#!/usr/bin/env perl

use warnings;
use strict;
use open qw(:std :utf8);
use utf8;
use Getopt::Long;
use XML::LibXML;
use XML::LibXML::PrettyPrint;


use File::Basename;
use File::Path;

use Lingua::Identify::Any qw/detect_text_language/;
use Data::Dumper;
my ($data_dir, $run_id, $config_path);


GetOptions (
            'data-dir=s' => \$data_dir,
            'id=s' => \$run_id,
            'config=s' => \$config_path
        );
my %config = map {m/^([^=]*)="(.*)"$/; $1 => $2} grep{m/^([^=]*)="(.*)"$/} split("\n",`./$config_path list`);

my $input_dir = $config{html2tei_text};
my $output_dir = $config{tei_lang};

unless($input_dir){
  print STDERR "no input directory\n";
  exit 1;
}


my @file_list = glob "$data_dir/$input_dir/$run_id/*_*.xml";
my @component_ids;

exit 1 unless @file_list;

`mkdir -p $data_dir/$output_dir/$run_id`;


for my $fileIn (@file_list){
  my $tei = open_xml($fileIn);
  for my $node ($tei->findnodes('.//*[local-name() = "seg"]')){
    my $text = $node->textContent();
    my $lng = detect_language($node,$text);
    my @check_context = ();
    push @check_context, status_lang($lng,$text,"too short, checking for context") if length($text) < 20;
    push @check_context, status_lang($lng,$text,"not confident") if $lng->{identify}->{conf}*1 < 0.8;
    push @check_context, status_lang($lng,$text,"different from uk") if $lng->{identify}->{lang} ne 'uk';
    if(not(defined $lng->{char}) and @check_context){
      print STDERR "INFO: ",$node->getAttributeNS('http://www.w3.org/XML/1998/namespace','id')," ",$check_context[0],"\n";
      $text = $node->parentNode->textContent();
      $lng = detect_language($node,$text);
      print STDERR "INFO: ",$node->getAttributeNS('http://www.w3.org/XML/1998/namespace','id')," ",status_lang($lng,$text, 'FIXED'),"\n";
    }
    my $lang = $lng->{char} // $lng->{identify}->{lang};
    unless($lang eq 'uk' or $lang eq 'ru'){
      print STDERR "WARN language[$lang]:$text\n";
    }
    $node->setAttributeNS('http://www.w3.org/XML/1998/namespace','lang',$lang);
  }
  # check if not "uk" speech was made by someone who speaks "uk"
  # TODO
  save_xml($tei,"$data_dir/$output_dir/$run_id/".basename($fileIn));
}

print STDERR (scalar @file_list)," files processed\n";

sub status_lang  {
  my($lng,$text,$msg) = @_;
  return sprintf("INFO: lang=%s\tconf=%s\tlen=%d\t%s",$lng->{identify}->{lang},$lng->{identify}->{conf},length($text),$msg//'');
}

sub detect_language {
  my ($node,$text) = @_;
  my %res;
  my $lng = detect_text_language(text => $text);
  if($text =~ m/[іїєґ]/i){
    $res{char} = 'uk';
  } elsif($text =~ m/[ыэъ]/i){
    $res{char} = 'ru';
  }
  $res{identify} = {conf => $lng->[2]->{confidence}, lang => $lng->[2]->{lang_code}};
  return \%res;
}
##-----------------------------

sub to_string {
  my $doc = shift;
  my $pp = XML::LibXML::PrettyPrint->new(
    indent_string => "   ",
    element => {
        inline   => [qw//], # note
        block    => [qw/person/],
        compact  => [qw/catDesc term label date edition title meeting idno orgName persName resp licence language sex forename surname measure head roleName/],
        preserves_whitespace => [qw/s seg note ref p desc name/],
        }
    );
  $pp->pretty_print($doc);
  return $doc->toString();
}


sub print_xml {
  my $doc = shift;
  binmode STDOUT;
  print to_string($doc);
}

sub save_xml {
  my ($doc,$filename) = @_;
  print STDERR "INFO: saving $filename\n";
  my $dir = dirname($filename);
  File::Path::mkpath($dir) unless -d $dir;
  open FILE, ">$filename";
  binmode FILE;
  my $raw = to_string($doc);
  print FILE $raw;
  close FILE;
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