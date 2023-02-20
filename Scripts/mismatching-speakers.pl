#!/usr/bin/env perl

use warnings;
use strict;
use open qw(:std :utf8);
use utf8;
use Getopt::Long;
use Text::CSV qw/csv/;
use File::Basename;
use File::Path;

use Data::Dumper;


my ($data_dir, $run_id, $config_path, $linking_file);
my $xmlNS = 'http://www.w3.org/XML/1998/namespace';

GetOptions (
            'data-dir=s' => \$data_dir,
            'id=s' => \$run_id,
            'config=s' => \$config_path,
            'linking=s' => \$linking_file, # tsv
        );
my %config = map {m/^([^=]*)="(.*)"$/; $1 => $2} grep{m/^([^=]*)="(.*)"$/} split("\n",`./$config_path list`);

my $input_dir = $config{link_speakers};
my $output_dir = $config{mismatching_speakers};

unless($input_dir){
  print STDERR "no input directory\n";
  exit 1;
}


my $mismatching = {};
if($linking_file){
  # fields:
  #    fileId
  #    utterance
  #    speaker
  #    aPersonId
  #    aRole
  #    aDayDist
  #    aEdDist
  #    sPersonId
  #    sRole
  #    sEdDist
  #    forename
  #    patronymic
  #    surname
  #    sex
  #    cIsFull
  #    cSurDist
  #    source
  $mismatching = {};
  for my $miss (grep {not($_->{aPersonId}) && not($_->{sPersonId}) } @{csv({in => $linking_file,headers => "auto", binary => 1, auto_diag => 1, sep_char=> "\t"})//[]}){
    $mismatching->{$miss->{speaker}} //= {};
    my $normalized_name = join(" ",grep map {$miss->{$_}} qw/forename patronymic surname/ );
    $mismatching->{$miss->{speaker}}->{$normalized_name} //= {
      cnt => 0,
      cIsFull => $miss->{cIsFull},
      cSurDist=> $miss->{cSurDist},
      seen => '',
      seenYears => {},
      sex => $miss->{sex},
      forename => $miss->{forename},
      patronymic => $miss->{patronymic},
      surname => $miss->{surname}
    };
    $mismatching->{$miss->{speaker}}->{$normalized_name}->{cnt} += 1;
    $mismatching->{$miss->{speaker}}->{$normalized_name}->{seen} .= $miss->{source}." ";
    my ($year) =$miss->{fileId} =~ m/^ParlaMint-UA_(\d{4})/;
    $mismatching->{$miss->{speaker}}->{$normalized_name}->{seenYears}->{$year} = 1;
  }
}



my $speaker_links_filename = "$data_dir/$output_dir/$run_id/mismatching-speakers.tsv";
open MISS, ">$speaker_links_filename";
print MISS "Cnt\tAliasInText\tForename\tPatronymic\tSurname\tSex\tSeenYears\tSeen\n";



for my $speaker (sort keys %$mismatching){
  print STDERR "$speaker\n";
  for my $name (sort {length($b) <=> length($a)} keys %{$mismatching->{$speaker}}){
    my $rec = $mismatching->{$speaker}->{$name};
    print MISS $rec->{cnt}."\t";
    print MISS "$speaker\t";
    print MISS $rec->{forename}."\t";
    print MISS $rec->{patronymic}."\t";
    print MISS $rec->{surname}."\t";
    print MISS $rec->{sex}."\t";
    print MISS join(" ", sort keys %{$rec->{seenYears}})."\t";
    print MISS $rec->{seen}."\n";
  }
}
close MISS;