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

use Data::Dumper;

my $max_edit_dist = 3;

my ($data_dir, $run_id, $config_path, $speaker_aliases_file,$speaker_calls_file, $plenary_speech_file);
my $xmlNS = 'http://www.w3.org/XML/1998/namespace';

GetOptions (
            'data-dir=s' => \$data_dir,
            'id=s' => \$run_id,
            'config=s' => \$config_path,
            'speaker-aliases=s' => \$speaker_aliases_file, # tsv
            'speaker-calls=s' => \$speaker_calls_file, # tsv
            'plenary-speech=s' => \$plenary_speech_file, # XML
        );
my %config = map {m/^([^=]*)="(.*)"$/; $1 => $2} grep{m/^([^=]*)="(.*)"$/} split("\n",`./$config_path list`);

my $input_dir = $config{html2tei_text};
my $output_dir = $config{link_speakers};

unless($input_dir){
  print STDERR "no input directory\n";
  exit 1;
}


my @file_list = sort glob "$data_dir/$input_dir/$run_id/*_*.xml";

exit 1 unless @file_list;

my @file_list_day;
while(my $f = shift @file_list){
  my ($day) = $f =~ m/^.*_(\d{4}-\d{2}-\d{2}).*?\.xml$/;
  my @day_files = ($f);
  while(@file_list && $file_list[0] =~ m/^.*_${day}[^\/]*?\.xml$/){
    push @day_files, shift @file_list;
  }
  push @file_list_day, [@day_files];
}

`mkdir -p $data_dir/$output_dir/$run_id`;

my $tsv = Text::CSV->new({binary => 1, auto_diag => 1, sep_char=> "\t"});

my $aliases;
if($speaker_aliases_file){
  $aliases = {};
  for my $al (@{csv({in => $speaker_aliases_file,headers => "auto", binary => 1, auto_diag => 1, sep_char=> "\t"})//[]}){
    $aliases->{uc $al->{alias}} //= {};
    $aliases->{uc $al->{alias}}->{$al->{term}} //= [];
    push @{$aliases->{uc $al->{alias}}->{$al->{term}}},{%$al,aliasUC => uc $al->{alias}};
  }
}

my $calls;
if($speaker_calls_file){
  for my $row (@{csv({in => $speaker_calls_file,headers => "auto", binary => 1, auto_diag => 1, sep_char=> "\t"}) //[] }) {
    $calls->{$row->{utterance}} //= $row;

    # taking longest name in calls:
    $calls->{$row->{utterance}} = $row if $calls->{$row->{utterance}}->{dist} > $row->{dist};
    $calls->{$row->{utterance}} = $row if  $calls->{$row->{utterance}}->{dist} = $row->{dist}
                  && length($calls->{$row->{utterance}}->{normalizedName}) < length($row->{normalizedName});
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
print SPEAKER_LINKS "fileId\tutterance\taPersonId\taRole\taTermDist\taEdDist\tsPersonId\tsRole\tsEdDist\tcNormalizedName\tcIsFull\tcSurDist\n";

for my $dayFilesIn (@file_list_day){
  my @utterances;
  my $tei_date; # shared over all files in same day
  for my $fileIn (@$dayFilesIn){
    my $tei = open_xml($fileIn);
    #my $tei_id = $tei->findvalue('/*[local-name() = "TEI"]/@xml:id');
    $tei_date = $tei->findvalue('//*[local-name() = "setting"]/*[local-name() = "date"]/@when');
    #my $tei_term = $tei->findvalue('//*[local-name() = "meeting" and contains(concat(" ",@ana," "),"#parla.term")]/@n');
    push @utterances,$_ for $tei->findnodes('//*[local-name() = "u"]');
  }
  my %linking;

  ### alias linking
  for my $node (@utterances){
    my $tei_term = $node->findvalue('./ancestor::*//*[local-name() = "meeting" and contains(concat(" ",@ana," "),"#parla.term")]/@n');
    my $who = $node->getAttribute('who');
    my $is_chair = ($node->getAttribute('ana') eq '#chair');
    my $alias_result = "";
    if(defined $aliases->{$who}){
      my $term_i = 0;
      my $term_dist;
      my $to_explore = scalar keys %{$aliases->{$who}} ;
      do {
        $term_i += 1;
        $term_dist = ($term_i % 2 == 0 ? -1 : 1 ) * int($term_i/2);
        $to_explore --;
      } until ($aliases->{$who}->{$tei_term +  $term_dist} || $to_explore <= 0 );
      if($aliases->{$who}->{$tei_term +  $term_dist}){
        my $is_teidate_in_any_alias_interval;
        my @spkr_list = map {
                              my $in_interval = is_in_date_interval($_,$tei_date);
                              $is_teidate_in_any_alias_interval //= $in_interval;
                              ({%$_, in_interval => $in_interval })
                            } @{$aliases->{$who}->{$tei_term +  $term_dist}};
        $alias_result .= "\t".join(" ",map {$_->{id}} grep {!$is_teidate_in_any_alias_interval || $_->{in_interval} } @spkr_list);
        $alias_result .= "\t".( $term_dist == 0
                                ? ( $is_chair
                                    ? 'chair'
                                    : ( $is_teidate_in_any_alias_interval
                                        ? 'regular'
                                        : 'guest'
                                      )
                                  )
                                : 'guest'
                              );
        $alias_result .= "\t".$term_dist;
        $alias_result .= "\t0";
        print STDERR join(" ",map {"(".$_->{from}."---".($_->{to}//"??").")"} @spkr_list),"$tei_date:  $alias_result\n" unless $is_teidate_in_any_alias_interval
      }
    }

    unless($alias_result){
      my @aliases_candidates = map {uc $_} grep {defined $aliases->{$_}->{$tei_term}} keys %$aliases;
      #my @closest_alias = amatch(uc "#####$who#####", ['20%'], @aliases_candidates);
      #my @closest_alias = map {$_/$len} distances(uc $who, @aliases_candidates);
      my %d;
      @d{@aliases_candidates} = map {$_} distance(uc $who, @aliases_candidates);
      my @sorted_candidates = sort { $d{$a} <=> $d{$b} } @aliases_candidates;
      my $min = $d{$sorted_candidates[0]};
      my @closest_alias = grep {$d{$_} <= 3 && $d{$_} <= $min} @sorted_candidates;
      my @spkr_list = map {@{$aliases->{$_}->{$tei_term}}} @closest_alias;
      if($min <= $max_edit_dist){
        $alias_result .= "\t".join(" ",map {$_->{id}} @spkr_list);
        $alias_result .= "\t".($is_chair ? 'chair' : 'regular');
        $alias_result .= "\t0";
        $alias_result .= "\t$min";
      }
    }
    $linking{$node->getAttributeNS($xmlNS,'id')} //= {};
    $linking{$node->getAttributeNS($xmlNS,'id')}->{alias} = $alias_result;
  }

  ### plenary speech linking
  my @plenary_speech_day = @{$speeches->{$tei_date} // []};
  if(@plenary_speech_day){
    my @speeches_non_chair = map { {alias => $_->getAttribute('who'),utterance => $_->getAttributeNS($xmlNS,'id')} }
                                 grep {$_->getAttribute('ana') !~ m/#chair\b/ }
                                      @utterances;
    my @aligned = align_seq([map {uc $_->{alias}} @plenary_speech_day],[map {$_->{alias}} @speeches_non_chair],10,1);
    for my $pair (@aligned){
      my ($i1,$i2) = @$pair;
      #print STDERR $plenary_speech_day[$i1]->{'parlamint-id'}," ",$plenary_speech_day[$i1]->{alias},"($i1)=($i2)",
      #             $speeches_non_chair[$i2]->{alias}," ",$speeches_non_chair[$i2]->{utterance},"\n";
      my $sdist = distance(uc $plenary_speech_day[$i1]->{alias},$speeches_non_chair[$i2]->{alias});
      if($sdist <= $max_edit_dist ){
        $linking{$speeches_non_chair[$i2]->{utterance}} //= {};
        $linking{$speeches_non_chair[$i2]->{utterance}}->{speech} =
            "\t".$plenary_speech_day[$i1]->{'parlamint-id'}
            ."\tregular\t$sdist";
      }
    }
  } else {
    print STDERR "INFO: day $tei_date is missing in plenary speech\n";
  }
  ### speaker calls linking
  for my $u (@utterances){
    my $u_id = $u->getAttributeNS($xmlNS,'id');
    if(defined $calls->{$u_id}){
      $linking{$u_id} //= {};
      $linking{$u_id}->{call} =
            "\t".$calls->{$u_id}->{normalizedName}
            ."\t".$calls->{$u_id}->{isFull}
            ."\t".$calls->{$u_id}->{dist};
    }
  }

  ### print result
  for my $u (@utterances){
    my $u_id = $u->getAttributeNS($xmlNS,'id');
    my $tei_id = $u->findvalue('./ancestor::*[local-name() = "TEI"]/@xml:id');
    print SPEAKER_LINKS
          "$tei_id\t$u_id",
          ($linking{$u_id}->{alias}||"\t\t\t\t"),
          ($linking{$u_id}->{speech}||"\t\t\t"),
          ($linking{$u_id}->{call}||"\t\t");
    print SPEAKER_LINKS "\n";
  }
}

print STDERR "INFO: ",(scalar @file_list)," files processed\n";
print STDERR "INFO: output file $speaker_links_filename\n";
close SPEAKER_LINKS;




sub align_seq { # Needleman-Wunsch algorithm
  my @s1 = @{shift//[]};
  my @s2 = @{shift//[]};
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