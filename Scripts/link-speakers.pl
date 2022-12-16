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


my @file_list = glob "$data_dir/$input_dir/$run_id/*_*.xml";

exit 1 unless @file_list;

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
  $calls = { map {$_->{utterance} => $_} @{csv({in => $speaker_calls_file,headers => "auto", binary => 1, auto_diag => 1, sep_char=> "\t"}) //[] } };
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
print SPEAKER_LINKS "fileId\tutterance\taliasPersonId\taliasRole\taliasTermDist\taliasEdDist\n";

for my $fileIn (@file_list){
  my $tei = open_xml($fileIn);
  my $tei_id = $tei->findvalue('/*[local-name() = "TEI"]/@xml:id');
  my $tei_date = $tei->findvalue('//*[local-name() = "setting"]/*[local-name() = "date"]/@when');
  my $tei_term = $tei->findvalue('//*[local-name() = "meeting" and contains(concat(" ",@ana," "),"#parla.term")]/@n');
  for my $node ($tei->findnodes('//*[local-name() = "u"]')){
    my $who = $node->getAttribute('who');
    my $is_chair = ($node->getAttribute('ana') eq '#chair');
    print SPEAKER_LINKS "$tei_id";
    print SPEAKER_LINKS "\t",$node->getAttributeNS($xmlNS,'id');
    my $alias_result = "";
    if(defined $aliases->{$who}){
      my $max_dist = 5;
      my $term_i = 0;
      my $term_dist;
      my $to_explore = scalar keys %{$aliases->{$who}} ;
      do {
        $term_i += 1;
        $term_dist = ($term_i % 2 == 0 ? -1 : 1 ) * int($term_i/2);
        $to_explore --;
      } until ($aliases->{$who}->{$tei_term +  $term_dist} || $to_explore <= 0 );
      if($aliases->{$who}->{$tei_term +  $term_dist}){
        my $spkr_list = $aliases->{$who}->{$tei_term +  $term_dist};
        $alias_result .= "\t".join(" ",map {$_->{id}} @$spkr_list);
        $alias_result .= "\t".($term_dist == 0 ? 'regular' : 'guest');
        $alias_result .= "\t".$term_dist;
        $alias_result .= "\t0";
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
      print STDERR "$who ~ '",join(" / ", @closest_alias),"' DIST=$min\n" if @closest_alias;
      if($min > $max_edit_dist){
        $alias_result .= "\t\t\t\t";
      } else {
        $alias_result .= "\t".join(" ",map {$_->{id}} @spkr_list);
        $alias_result .= "\tregular";
        $alias_result .= "\t0";
        $alias_result .= "\t$min";
      }
    }
    print SPEAKER_LINKS "$alias_result\n";
  }
}

print STDERR "INFO: ",(scalar @file_list)," files processed\n";
print STDERR "INFO: output file $speaker_links_filename\n";
close SPEAKER_LINKS;



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