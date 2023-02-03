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


my ($in,$out);

GetOptions (
            'in=s' => \$in,
            'out=s' => \$out,
        );

my $INPUT;
my $OUTPUT;

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

my $tsv_in = Text::CSV->new ({ binary => 1, auto_diag => 1, sep_char=> "\t" });
$tsv_in->header ($INPUT, { munge_column_names => "none" });

print STDERR join(' ',$tsv_in->column_names()),"\n";

my $tsv_out = Text::CSV->new ({ binary => 1, auto_diag => 1, sep_char=> "\t", eol => $/, quote_char => undef });
$tsv_out->column_names(qw/doc utterance who ana/);
$tsv_out->print($OUTPUT,[$tsv_out->column_names]);

while(my $row = $tsv_in->getline_hr ($INPUT)){
  my $result={};
  $result->{doc} = $row->{fileId};
  $result->{utterance} = $row->{utterance};
  $result->{who} = $row->{aPersonId} || $row->{sPersonId};
  $result->{ana} = $row->{aRole} || $row->{sRole};
  #print STDERR "WARN: "
  $tsv_out->print_hr ($OUTPUT, $result);

  if($row->{aPersonId} =~ m/ /){
    print STDERR Dumper($row);
    last
  }
}








close $INPUT if $in;
close $OUTPUT if $out;