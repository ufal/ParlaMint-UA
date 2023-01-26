#!/usr/bin/env perl

use warnings;
use strict;
use open qw(:std :utf8);
use utf8;
use Getopt::Long;
use XML::LibXML;
use Text::CSV qw/csv/;
use Text::Levenshtein qw(distance);
use File::Basename;
use File::Path;
use DateTime;

use Data::Dumper;

my $max_edit_dist = 3;

my ($data_dir, $run_id, $config_path, $input_dir, $output_dir, $linking_file, $speaker_aliases_file,$speaker_calls_file, $plenary_speech_file);
my $xmlNS = 'http://www.w3.org/XML/1998/namespace';

my @header_common = qw/date fileId utterance speaker ana/;
my @header_alias = qw/aPersonId aRole aDayDist aEdDist/;
my @header_speech = qw/sPersonId sRole sEdDist/;
my @header_call = qw/forename patronymic surname sex cIsFull cSurDist/;
my @header = (
               @header_common,
               @header_alias,
               @header_speech,
               @header_call,
               'source'
            );

GetOptions (
            'data-dir=s' => \$data_dir,
            'in-dir-name=s' => \$input_dir,
            'out-dir-name=s' => \$output_dir,
            'id=s' => \$run_id,
            'config=s' => \$config_path,
            'linking=s' => \$linking_file, #tsv
            'speaker-aliases=s' => \$speaker_aliases_file, # tsv
            'speaker-calls=s' => \$speaker_calls_file, # tsv
            'plenary-speech=s' => \$plenary_speech_file, # XML
        );
my %config = map {m/^([^=]*)="(.*)"$/; $1 => $2} grep{m/^([^=]*)="(.*)"$/} split("\n",`./$config_path list`);

unless($input_dir){
  print STDERR "no input directory\n";
  exit 1;
}

unless($output_dir){
  print STDERR "no output directory\n";
  exit 1;
}

my ($teiCorpus_fileIn) = glob "$data_dir/$input_dir/$run_id/ParlaMint-UA.xml";
unless($teiCorpus_fileIn){
  print STDERR "no input corpus file $data_dir/$input_dir/$run_id/ParlaMint-UA.xml\n";
  exit 1;
}
my $teiCorpus = open_xml($teiCorpus_fileIn);

die "invalid corpus file" unless $teiCorpus;

my @file_list = sort map {"$data_dir/$input_dir/$run_id/".$_->getAttribute('href')} $teiCorpus->findnodes('/*[local-name() = "teiCorpus"]/*[local-name() = "include" and @href]');

exit 1 unless @file_list;

my @file_list_day;
while(my $f = shift @file_list){
  my ($day) = $f =~ m/^.*_(\d{4}-\d{2}-\d{2}).*?\.xml$/;
  my @day_files = ($f);
  while(@file_list && $file_list[0] =~ m/^.*_${day}[^\/]*?\.xml$/){
    push @day_files, shift @file_list;
  }
  push @file_list_day, {date=>$day, files=>[@day_files]};
}

`mkdir -p $data_dir/$output_dir/$run_id`;

my $tsv = Text::CSV->new({binary => 1, auto_diag => 1, sep_char=> "\t"});

if($linking_file && $plenary_speech_file){
  print STDERR "ERROR: invalid option combination --linking <PATH> --plenary-speech <PATH>\n";
  exit 1;
}
if($linking_file && $speaker_calls_file){
  print STDERR "ERROR: invalid option combination (not implemented) --linking <PATH> --speaker-calls <PATH>\n";
  exit 1;
}

my %all_linking;
if($linking_file){
  my $ord = 0;
  print STDERR "INFO: loading existing linking: $linking_file\n";
  for my $row (@{csv({in => $linking_file,headers => "auto", binary => 1, auto_diag => 1, sep_char=> "\t"})//[]}){
    my $u_id = $row->{utterance};
    $all_linking{$u_id} = {
      ord => ++$ord,
      common => {
          map {$_ => $row->{$_}} (@header_common,'source')
        },
      alias => {
          map {$_ => $row->{$_}} @header_alias
        },
      call => {
          map {$_ => $row->{$_}} @header_call
        },
      speech => {
          map {$_ => $row->{$_}} @header_speech
        },
    };
  }
}

my $aliases;
if($speaker_aliases_file){
  $aliases = {};
  for my $al (@{csv({in => $speaker_aliases_file,headers => "auto", binary => 1, auto_diag => 1, sep_char=> "\t"})//[]}){
    $aliases->{uc $al->{alias}} //= {};
    $aliases->{uc $al->{alias}}->{$al->{id}} //= [];
    if($al->{org}){ # if organization is not defined, then no period is used
      my $from = convert_to_days($al->{from} || '1970-01-01');
      my $to = convert_to_days($al->{to} || '2070-12-12');
      push @{$aliases->{uc $al->{alias}}->{$al->{id}}},[$from,$to]
    }
  }
}

my $calls;
if($speaker_calls_file){
  for my $row (@{csv({in => $speaker_calls_file,headers => "auto", binary => 1, auto_diag => 1, sep_char=> "\t"}) //[] }) {
    $row->{$_} //= '' for @header_call;
    $calls->{$row->{utterance}} //= $row;

    # taking longest name in calls:
    $calls->{$row->{utterance}} = $row if $calls->{$row->{utterance}}->{dist} > $row->{dist};
    $calls->{$row->{utterance}} = $row if  $calls->{$row->{utterance}}->{dist} == $row->{dist}
                  && length(join(' ',grep $calls->{$row->{utterance}}->{qw/forename patronymic surname/})) < length(join(' ',grep $row->{qw/forename patronymic surname/}));
  }
}

my $speeches;
if($plenary_speech_file){
  my $xml_sp = open_xml($plenary_speech_file);
  $speeches = {};
  for my $sp (sort {$a->getAttribute('datetime') cmp $b->getAttribute('datetime')} $xml_sp->findnodes('//speech')){
    $speeches->{$sp->getAttribute('date')} //= [];
    push @{$speeches->{$sp->getAttribute('date')}},{ map {$_->getName => $_->getValue} $sp->attributes };
  }
}

my $speaker_links_filename = "$data_dir/$output_dir/$run_id/speaker-person-links.tsv";
open SPEAKER_LINKS, ">$speaker_links_filename";
print SPEAKER_LINKS join("\t",@header)."\n";

for my $dayFilesIn (@file_list_day){
  my @utterances;
  my %linking;
  my $tei_date = $dayFilesIn->{date}; # shared over all files in same day
  if($linking_file){
    for my $record (sort {$a->{ord} <=> $b->{ord}} grep {$_->{common}->{date} eq $tei_date} values %all_linking){
      my $u_id = $record->{common}->{utterance};
      push @utterances,$u_id;
      $linking{$u_id} = $record;
    }
  } else {
    for my $fileIn (@{$dayFilesIn->{files}}){
      my $tei = open_xml($fileIn);
      my $tei_id = $tei->findvalue('/*[local-name() = "TEI"]/@xml:id');
      #$tei_date = $tei->findvalue('//*[local-name() = "setting"]/*[local-name() = "date"]/@when');
      #my $tei_term = $tei->findvalue('//*[local-name() = "meeting" and contains(concat(" ",@ana," "),"#parla.term")]/@n');
      for my $u ($tei->findnodes('//*[local-name() = "u"]')){
        my $u_id = $u->getAttributeNS($xmlNS,'id');
        my $who = $u->getAttribute('who');
        my $ana = $u->getAttribute('ana');
        my $source = $u->findvalue('./ancestor::*[local-name() = "TEI"]//*[local-name() = "bibl"]/*[local-name() = "idno"]');
        push @utterances,$u_id;
        $linking{$u_id} = {};
        #columns: fileId utterance speaker
        $linking{$u_id}->{common} = {
          fileId => $tei_id,
          utterance => $u_id,
          speaker => $who,
          ana => $ana,
          date => $tei_date,
          source => $source,
        }
      }
    }
  }
  my $tei_date_num = convert_to_days($tei_date);

  ### alias linking
  my %seen_alias;
  for my $u_id (@utterances){
    my $who = $linking{$u_id}->{common}->{speaker};
    my $is_chair = ($linking{$u_id}->{common}->{ana} eq '#chair');
    my $alias_result;
    if($seen_alias{$who}){
      $alias_result = $seen_alias{$who}
    }
    # check intervals, use in interval first (as regular or chair), otherwise set guest
    my %res;
    my $act_max_edit_dist;
    my $minedist;
    my @wh;
    my @edit_dists = (0,$max_edit_dist);
    while(!$alias_result && defined($act_max_edit_dist = shift @edit_dists)){
      if($act_max_edit_dist == 0){
        @wh=($who);
        $minedist = 0
      } else {
        my @aliases_candidates = map {uc $_} keys %$aliases;
        my %d;
        @d{@aliases_candidates} = map {$_} distance(uc $who, @aliases_candidates);
        my @sorted_candidates = sort { $d{$a} <=> $d{$b} } @aliases_candidates;
        $minedist = $d{$sorted_candidates[0]};
        @wh = grep {$d{$_} <= $act_max_edit_dist && $d{$_} <= $minedist} @sorted_candidates;
      }

      for my $wh (@wh){
        for my $pers_id (keys %{$aliases->{$wh} // {}}){
          for my $interval (@{$aliases->{$wh}->{$pers_id}}){
            if($tei_date_num >= $interval->[0] and $tei_date_num <= $interval->[1]){
              # can be multiple results (other ids)
              $res{$pers_id} = {dist=>0, id=>$pers_id, interval=>$interval};
              last;
            } else {
              my $dist;
              if($tei_date_num < $interval->[0]){
                $dist = $interval->[0]-$tei_date_num;
              } else {
                $dist = $tei_date_num-$interval->[1];
              }
              $res{$pers_id} = {dist=> $dist, id=>$pers_id, interval=>$interval} unless defined $res{$pers_id};
              $res{$pers_id} = {dist=> $dist, id=>$pers_id, interval=>$interval} if $res{$pers_id}->{dist} > $dist
            }
          }
          # add if no interval
          unless(@{$aliases->{$wh}->{$pers_id}}){
            $res{$pers_id} = {id => $pers_id} unless defined $res{$pers_id}
          }
        }
      }
      my $mindist;
      for my $dist (map {$_->{dist}} values %res){
        $mindist //= $dist;
        $mindist = $dist if defined($dist) && $mindist > $dist;
      }
      if(%res){
        #columns: aPersonId aRole aDayDist aEdDist
        $alias_result = {
          aPersonId => join(" ",map {$_->{id}} grep {!defined($mindist) || $_->{dist} == $mindist} values %res),
          aRole => ($is_chair ? '#chair' : ($mindist//9999 > 0 ? '#guest' : '#regular')),
          aDayDist => ($mindist//''),
          aEdDist => $minedist,
        };
        $seen_alias{$who} = $alias_result;
        last;
      }
    }

    $linking{$u_id} //= {};
    if($linking{$u_id}->{alias} && ($linking{$u_id}->{alias}->{aPersonId}//'') ne ($alias_result->{aPersonId}//'') ){
      print STDERR "INFO: $u_id replacing '",$linking{$u_id}->{alias}->{aPersonId},"' with '",($alias_result->{aPersonId}//''),"\n";
    }
    $linking{$u_id}->{alias} = $alias_result;
  }

  ### plenary speech linking
  my @plenary_speech_day = @{$speeches->{$tei_date} // []};
  if(@plenary_speech_day){
    my @speeches_non_chair = map { {alias => $linking{$_}->{common}->{speaker},utterance => $_} }
                                 grep {$linking{$_}->{common}->{ana} !~ m/#chair\b/ }
                                      @utterances;
    my @aligned = align_seq([map {uc $_->{alias}} @plenary_speech_day],[map {$_->{alias}} @speeches_non_chair],10,1);
    for my $pair (@aligned){
      my ($i1,$i2) = @$pair;
      #print STDERR $plenary_speech_day[$i1]->{'parlamint-id'}," ",$plenary_speech_day[$i1]->{alias},"($i1)=($i2)",
      #             $speeches_non_chair[$i2]->{alias}," ",$speeches_non_chair[$i2]->{utterance},"\n";
      my $sdist = distance(uc $plenary_speech_day[$i1]->{alias},$speeches_non_chair[$i2]->{alias});
      if($sdist <= $max_edit_dist ){
        $linking{$speeches_non_chair[$i2]->{utterance}} //= {};
        #columns: sPersonId sRole sEdDist
        $linking{$speeches_non_chair[$i2]->{utterance}}->{speech} ={
          sPersonId => $plenary_speech_day[$i1]->{'parlamint-id'},
          sRole => '#regular',
          sEdDist => $sdist,

        };
      }
    }
  } else {
    print STDERR "INFO: day $tei_date is missing in plenary speech\n";
  }
  ### speaker calls linking
  for my $u_id (@utterances){
    if(defined $calls->{$u_id}){
      $linking{$u_id} //= {};
      #columns: forename patronymic surname sex cIsFull cSurDist
      $linking{$u_id}->{call} = {
        forename => $calls->{$u_id}->{forename},
        patronymic => $calls->{$u_id}->{patronymic},
        surname => $calls->{$u_id}->{surname},
        sex => $calls->{$u_id}->{sex},
        cIsFull => $calls->{$u_id}->{isFull},
        cSurDist => $calls->{$u_id}->{dist},
      }
    }
  }

  ### print result
  for my $u_id (@utterances){
    print SPEAKER_LINKS
          join("\t", map {$linking{$u_id}->{common}->{$_} // ''} @header_common),
          "\t",
          join("\t", map {$linking{$u_id}->{alias}->{$_} // ''} @header_alias),
          "\t",
          join("\t", map {$linking{$u_id}->{speech}->{$_} // ''} @header_speech),
          "\t",
          join("\t", map {$linking{$u_id}->{call}->{$_} // ''} @header_call),
          "\t",
          $linking{$u_id}->{common}->{source};
    print SPEAKER_LINKS "\n";
  }
}

print STDERR "INFO: ",(scalar @file_list)," files processed\n";
print STDERR "INFO: output file $speaker_links_filename\n";
close SPEAKER_LINKS;




sub align_seq { # Needleman-Wunsch algorithm
  my @s1 = @{shift//[]};
  my @s2 = @{shift//[]};
  return () unless @s1 && @s2;
  my ($gap_penalty1,$gap_penalty2) = (@_,10,10);
  my @alignment = ();
  my @dist = map { [(0) x ($#s2 + 1)] }  (0..$#s1);
  $dist[$_]->[0] = $_ * $gap_penalty1 for (0..$#s1);
  $dist[0]->[$_] = $_ * $gap_penalty2 for (0..$#s2);

  for my $i (1..$#s1){
    for my $j (1..$#s2) {
      if($s1[$i-1] eq $s2[$j-1]){
        $dist[$i]->[$j] = $dist[$i-1]->[$j-1]
      } else {
        $dist[$i]->[$j] =List::Util::min($dist[$i-1]->[$j-1] + distance($s1[$i], $s2[$j]),
                                         $dist[$i-1]->[$j] + $gap_penalty1,
                                         $dist[$i]->[$j-1] + $gap_penalty2);
      }
    }
  }

  my ($i,$j) = ($#s1,$#s2);
  while(!($i==0 || $j==0)) {
    if($s1[$i-1] eq $s2[$j-1]){
      $i--;
      $j--;
    } elsif ($dist[$i-1]->[$j-1] + distance($s1[$i], $s2[$j]) == $dist[$i]->[$j]) {
      $i--;
      $j--;
    } elsif ($dist[$i-1]->[$j] + $gap_penalty1 == $dist[$i]->[$j]) {
      $i--;
    } elsif ($dist[$i]->[$j-1] + $gap_penalty2 == $dist[$i]->[$j]) {
      $j--;
    }
    push @alignment, [$i,$j];
  }
  push @alignment, [--$i,$j] while $i > 0;
  push @alignment, [$i,--$j] while $j > 0;

  return reverse @alignment;
}

sub is_in_date_interval {
  my ($interval,$date) = @_;
  my $is_in_interval = 1;
  undef $is_in_interval if defined($interval->{from}) && $interval->{from} && ($interval->{from} gt $date);
  undef $is_in_interval if defined($interval->{to}) && $interval->{to} && ($interval->{to} lt $date);

  return $is_in_interval;
}

sub convert_to_days {
  my $dt = shift;
  my ($y,$m,$d) = split('-',$dt);
  return DateTime->new(year=>$y, month=>$m, day=>$d)->epoch / 60 / 60 / 24;
}
##-----------------------------

sub open_xml {
  my $file = shift;
  print STDERR "INFO: opening $file\n";
  my $xml;
  local $/;
  open FILE, $file;
  binmode ( FILE, ":utf8" );
  my $rawxml = <FILE>;
  close FILE;

  if ((! defined($rawxml)) || $rawxml eq '' ) {
    print " -- empty file $file\n";
  } else {
    my $parser = XML::LibXML->new();
    my $doc = "";
    eval { $doc = $parser->load_xml(string => $rawxml); };
    if ( !$doc ) {
      print " -- invalid XML in $file\n";
      print "$@";

    } else {
      $xml = $doc
    }
  }
  return $xml
}