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


my ($in,$out,$fallback_tsv);

GetOptions (
            'in=s' => \$in,
            'fallback=s' => \$fallback_tsv,
            'out=s' => \$out,
        );

my $INPUT;
my $OUTPUT;
my $fallback = {};

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
    $fallback->{$row->{date}} = {};
    $fallback->{$row->{date}}->{$row->{alias}} = {
      ana => $row->{ana},
      who => $row->{who}
    };
  }
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
  $result->{who} = $row->{aPersonId} || $row->{sPersonId} || get_fallback($row->{date},$row->{speaker},'who');
  $result->{ana} = $row->{aRole} || $row->{sRole} || get_fallback($row->{date},$row->{speaker},'ana');;
  #print STDERR "WARN: "
  $tsv_out->print_hr ($OUTPUT, $result);

  if($row->{aPersonId} =~ m/ /){
    print STDERR Dumper($row);
  }
}


close $INPUT if $in;
close $OUTPUT if $out;


sub get_fallback {
  my ($date,$speaker,$field) = @_;
  return '' unless $fallback->{$date};
  return '' unless $fallback->{$date}->{$speaker};
  return $fallback->{$date}->{$speaker}->{$field};
}