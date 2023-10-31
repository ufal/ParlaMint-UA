#!/usr/bin/env perl

use warnings;
use strict;
use open qw(:std :utf8);
use utf8;
use Getopt::Long qw(:config);
use Text::CSV qw/csv/;
use XML::LibXML;
use XML::LibXML::PrettyPrint;
use File::Basename;
use File::Path;

use Ufal::UDPipe;

use Data::Dumper;

my $xmlNS = 'http://www.w3.org/XML/1998/namespace';

my ($data_dir, $run_id, $config_path, $model_path, $debug);

GetOptions (
            'data-dir=s' => \$data_dir,
            'id=s' => \$run_id,
            'config=s' => \$config_path,
            'model=s' => \$model_path,
            'debug' => \$debug,
        );
my %config = map {m/^([^=]*)="(.*)"$/; $1 => $2} grep{m/^([^=]*)="(.*)"$/} split("\n",`./$config_path list`);

my $input_dir = $config{html2tei_text};
my $output_tsv_dir = $config{tsv_sentences};
my $output_tei_dir = $config{tei_sentences};

unless($input_dir){
  print STDERR "no input directory\n";
  exit 1;
}

unless($model_path){
  print STDERR "no model\n";
  exit 1;
}
my $model = Ufal::UDPipe::Model::load($model_path);
$model or die "Cannot load model '$model_path'\n";
my $tokenizer = $model->newTokenizer($Ufal::UDPipe::Model::DEFAULT);
my $sentence = Ufal::UDPipe::Sentence->new();

$input_dir = "$data_dir/$input_dir/$run_id";
my ($teiCorpus_fileIn) = glob "$input_dir/ParlaMint-UA.xml";
unless($teiCorpus_fileIn){
  print STDERR "no input corpus file $input_dir/ParlaMint-UA.xml\n";
  exit 1;
}
my $teiCorpus = open_xml($teiCorpus_fileIn);

die "invalid corpus file" unless $teiCorpus;

my @file_list = map {$_->getAttribute('href')} $teiCorpus->findnodes('/*[local-name() = "teiCorpus"]/*[local-name() = "include" and @href]');

exit 1 unless @file_list;

$output_tsv_dir = "$data_dir/$output_tsv_dir/$run_id";
$output_tei_dir = "$data_dir/$output_tei_dir/$run_id";

`mkdir -p $output_tsv_dir`;
`mkdir -p $output_tei_dir`;


my $tsv = Text::CSV->new({binary => 1, auto_diag => 1, sep_char=> "\t", quote_char => undef, escape_char => undef});

for my $file (@file_list){
  my $tei = open_xml("$input_dir/$file");
  my $tei_filepath = "$output_tei_dir/$file";
  my $tsv_filepath = "$output_tsv_dir/$file";
  $tsv_filepath =~ s/\.xml$/.tsv/;
  my $tsvdir = dirname($tsv_filepath);
  File::Path::mkpath($tsvdir) unless -d $tsvdir;
  my $TSV;
  open $TSV, ">$tsv_filepath";
  binmode $TSV, ":encoding(UTF-8)";
  $tsv->say($TSV,[qw/id text/]);
  for my $node ($tei->findnodes('.//*[local-name() = "seg"]')){
    my $segId = $node->getAttributeNS($xmlNS,'id');

    my @childNodes = $node->childNodes();
    my $text = join('', grep {ref $_ eq 'XML::LibXML::Text'} @childNodes);
    print STDERR "SEG: ($segId)$text\n" if $debug;
    my @sentences = split_to_sentences($text);
    $_->unbindNode for @childNodes;
    #my ($chIdx,$sIdx,$in_sIdx,$textIdx) = (0,0,0,0);
    my ($nodeIdx,$sentenceIdx,$sentencePos,$textPos) = (0,0,0,0);
    my $sentNode;
    my $curText;
    my @stack = ($node);
    while($nodeIdx < @childNodes or $sentenceIdx < @sentences){
      print STDERR "LOOP: ($nodeIdx)nodeIdx\t($sentenceIdx)sentenceIdx\t($sentencePos)sentencePos\n" if $debug;
      print STDERR "SENTENCE: ",substr($sentences[$sentenceIdx],0,$sentencePos),"[[$sentencePos]]",substr($sentences[$sentenceIdx],$sentencePos),"\n" if $debug;
      print STDERR "\tsentenceLen=",length($sentences[$sentenceIdx]),"\n" if $debug;
      if ($nodeIdx <= $#childNodes and ref $childNodes[$nodeIdx] eq 'XML::LibXML::Element'){ # insert note
        print STDERR "\tNOTE\n" if $debug;
        $stack[0] -> appendChild($childNodes[$nodeIdx]);
        $nodeIdx++;
      } elsif ($nodeIdx <= $#childNodes and ref $childNodes[$nodeIdx] eq 'XML::LibXML::Text') { # processing text
        if(not defined $curText){
          $curText = $childNodes[$nodeIdx]->textContent();
        } elsif ($curText eq '') {
          undef $curText;
          $nodeIdx++;
        }
        if (length($sentences[$sentenceIdx]) <= $sentencePos) { # close sentence (in_sIdx point after sentence)
          print STDERR "\tCLOSE SENTENCE sentenceLen=",length($sentences[$sentenceIdx]),"\n" if $debug;
          # close sentence if present
          $sentenceIdx++;
          shift @stack;
          $sentencePos = 0;
        } elsif (($curText//'') =~ m/^\s/ ) { # space before/inside of sentence
          $curText =~ s/^(\s)//;
          $stack[0]->appendText($1);
        } elsif(defined $curText) {
          print STDERR "\tINSIDE SENTENCE ($sentencePos)$sentences[$sentenceIdx]\n" if $debug;
          if ($sentencePos == 0) { # start sentence
            # create new sentence node and unshift it in stack
            $sentNode = $node->addNewChild($node->namespaceURI(),'tmpSentence');
            my $sID = sprintf("%s.sent%d",$segId,$sentenceIdx + 1);
            print STDERR "$nodeIdx\t$sID\t$sentences[$sentenceIdx]\n" if $debug;
            $tsv->say($TSV,[($sID,$sentences[$sentenceIdx])]);
            $sentNode->setAttributeNS($xmlNS,'id',$sID);
            unshift @stack, $sentNode;
          }
          # get longest common prefix of text and sentence
          my $prefix_len = get_prefix_len($curText, substr($sentences[$sentenceIdx],$sentencePos));
          my $common_prefix = substr($curText,0,$prefix_len);
          # remove common prefix from text

          print STDERR "($sentencePos)'$curText'\t$prefix_len\t" if $debug;
          $curText = substr($curText,$prefix_len);
          # move in_sIdx
          $sentencePos += $prefix_len;
          print STDERR "($sentencePos)'$curText'\n" if $debug;
          # append common prefix to sentNode
          $sentNode->appendText($common_prefix);
        }
      } else {
        print STDERR "ERROR: ",ref $childNodes[$nodeIdx],"\n";
      }
    }
  }
  print STDERR "INFO: saving $tsv_filepath\n";
  close $TSV;
  save_xml($tei,"$output_tei_dir/$file");
}


sub get_prefix_len {
  my ($a,$b) = (@_,'','');
  my $len = 0;
  ++$len until $len > length($a) or substr($b, 0, $len) ne substr($a, 0, $len);
  return $len - 1;
}

sub split_to_sentences {
  my $text = shift // '';
  my @sentences;
  $tokenizer->setText($text);
  while($tokenizer->nextSentence($sentence)){
    push @sentences, $sentence->getText();
  }
  return @sentences;
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