#!/usr/bin/env perl

use warnings;
use strict;
use open qw(:std :utf8);
use utf8;
use Getopt::Long;
use Text::CSV qw/csv/;
use Text::Levenshtein qw(distance);
use XML::LibXML;
use File::Basename;
use File::Path;
use List::Util;
use Data::Dumper;


my ($in,$out,$fallback_tsv,$listPerson_xml);

GetOptions (
            'in=s' => \$in,
            'fallback=s' => \$fallback_tsv,
            'listPerson=s' => \$listPerson_xml,
            'out=s' => \$out,
        );

my %label_map = (
  forename => 'forename',
  patronym => 'patronymic',
  surname => 'surname',
  );

my $INPUT;
my $OUTPUT;
my $fallback = {};
my $listPerson;

if($in){
  open $INPUT,"<$in" or die "ERROR: unable to open file for reading: $in";
} else {
  $INPUT = *STDIN;
}

if($out){
  open $OUTPUT,">$out" or die "ERROR: unable to open file for writing: $out";
} else {
  $OUTPUT = *STDOUT;
}

if($fallback_tsv){
  open my $FH, "<$fallback_tsv" or die "ERROR: unable to open file for reading: $$fallback_tsv";
  my $tsv_fb = Text::CSV->new ({ binary => 1, auto_diag => 1, sep_char=> "\t" });
  $tsv_fb->header ($FH, { munge_column_names => "none" });
  while(my $row = $tsv_fb->getline_hr ($FH)){
    my $speaker = $row->{alias};
    $speaker =~ s/\.*$//;
    $fallback->{$row->{date}} = {};
    $fallback->{$row->{date}}->{$speaker} = {
      ana => $row->{ana},
      who => $row->{who}
    };
  }
}

if($listPerson_xml){
  $listPerson = open_xml($listPerson_xml);
}

my $tsv_in = Text::CSV->new ({ binary => 1, auto_diag => 1, sep_char=> "\t" });
$tsv_in->header ($INPUT, { munge_column_names => "none" });

print STDERR join(' ',$tsv_in->column_names()),"\n";

my $tsv_out = Text::CSV->new ({ binary => 1, auto_diag => 1, sep_char=> "\t", eol => $/, quote_char => undef });
$tsv_out->column_names(qw/doc utterance who ana alias date source/);
$tsv_out->print($OUTPUT,[$tsv_out->column_names]);

my $row;
my @rows;
my $date;
do {
  # read all records from one day
  while (
    ($row = $tsv_in->getline_hr($INPUT))
    &&
    $date
    &&
    $date eq $row->{date}
    ){
    push @rows, $row;
  }
  $date = $row->{date} if $row;

  my %results;
  my %aliases_mapping;
  for my $record (@rows){
    my $result={};
    $result->{doc} = $record->{fileId};
    $result->{utterance} = $record->{utterance};
    $result->{who} = $record->{aPersonId};
    $result->{ana} = $record->{aRole};
    $result->{alias} = $record->{speaker};
    $result->{date} = $record->{date};
    $result->{source} = $record->{source};

    if(($result->{who} eq '' || $result->{who} =~ m/ /) && $record->{sPersonId}){
      $result->{who} = $record->{sPersonId};
      $result->{ana} = $record->{sRole};
    }

    if($result->{who} =~ m/ / && $record->{surname}){
      # if multiple candidates, then decide based on call speaker
      # delete who and ana if the distance is too large
      # read from listPerson

      my %candidates = map {$_ => {text => get_persName($_)} } split(' ',$result->{who});
      my $min_dist;
      for my $id (keys %candidates){
        $candidates{$id}->{dists} = [
            map {
              my $type = $_;
              my ($field) = map {$_->{text} } grep {$_->{type} eq $type} @{$candidates{$id}->{text}->[0]};
              distance($field//'', $record->{$label_map{$type}})
              } qw/forename patronym surname/
          ];
        $candidates{$id}->{dist} = List::Util::sum(@{$candidates{$id}->{dists}});
        $min_dist //= $candidates{$id}->{dist};
        $min_dist = $candidates{$id}->{dist} if $min_dist > $candidates{$id}->{dist};
      }

      my @who = grep {$candidates{$_}->{dist} == $min_dist} keys %candidates;
      if(scalar(@who) == 1){
        $result->{who} = shift @who;
      }
    }

    if($result->{who} eq '' || $result->{who} =~ m/ /){
      $result->{who} = get_fallback($record->{date},$record->{speaker},'who');
      $result->{ana} = get_fallback($record->{date},$record->{speaker},'ana');
    }

    $results{$result->{utterance}} = $result;

    $aliases_mapping{$record->{speaker}} //= {};
    if($result->{who}){
      $aliases_mapping{$record->{speaker}}->{$result->{who}} //= {};
      $aliases_mapping{$record->{speaker}}->{$result->{who}}->{cnt} //= 0;
      $aliases_mapping{$record->{speaker}}->{$result->{who}}->{cnt} += 1;
      $aliases_mapping{$record->{speaker}}->{$result->{who}}->{ana} //= {};
      $aliases_mapping{$record->{speaker}}->{$result->{who}}->{ana}->{$result->{ana}} //= 0;
      $aliases_mapping{$record->{speaker}}->{$result->{who}}->{ana}->{$result->{ana}} += 1;

    }
  }

  for my $record (@rows){
    my $result = $results{$record->{utterance}};
    if(not($result->{who}) or $result->{who} =~ m/ /){
      my @cnts = map {$_->{cnt} } values %{$aliases_mapping{$record->{speaker}} // {}};
      if(scalar @cnts){
        my $max_cnt = List::Util::max(@cnts);
        my @who = grep {$aliases_mapping{$record->{speaker}}->{$_}->{cnt} == $max_cnt} keys %{$aliases_mapping{$record->{speaker}} // {}};
        if(scalar(@who) == 1){
          $result->{who} = shift @who;
          $result->{ana} = join(' ', keys %{$aliases_mapping{$record->{speaker}}->{$result->{who}}->{ana}//{}});
        }
      } else {
        print STDERR "WARN: no match ",join("\t",map {$record->{$_}} qw/date fileId utterance ana speaker source/),"\n";
        print STDERR "\tALIAS:   ",join("\t",map {$record->{$_}||'-'} qw/aDayDist aEdDist aRole aPersonId/),"\n";
        print STDERR "\tPLENARY: ",join("\t",map {$record->{$_}||'-'} qw/sEdDist sRole sPersonId/),"\n";
        print STDERR "\tCALL:    ",join("\t",map {$record->{$_}||'-'} qw/cSurDist forename patrynomic surname sex/),"\n";
      }
    }
    $tsv_out->print_hr ($OUTPUT, $result);
  }


  @rows = ();
  @rows =($row) if $row;
} while (@rows);


close $INPUT if $in;
close $OUTPUT if $out;


sub get_fallback {
  my ($date,$speaker,$field) = @_;
  $speaker =~ s/\.*$//;
  return '' unless $fallback->{$date};
  return '' unless defined $fallback->{$date}->{$speaker};
  return $fallback->{$date}->{$speaker}->{$field};
}

sub get_persName {
  my $id = shift;
  $id =~ s/#//;
  my @persNames = map {
    [ map {({text => $_->textContent, type => $_->hasAttribute('type') ? $_->getAttribute('type') : $_->nodeName }) } grep {ref $_ eq 'XML::LibXML::Element'}$_->childNodes]
    } $listPerson->findnodes('//*[name() = "person" and @xml:id="'.$id.'"]/*[name() = "persName"]');
  return [@persNames]
}

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