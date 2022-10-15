#!/usr/bin/env perl

use warnings;
use strict;
use open qw(:std :utf8);
use utf8;
use Getopt::Long;
use DateTime::Format::Strptime;
use XML::LibXML;
use XML::LibXML::PrettyPrint;
use Encode;
use HTML::Entities;

my ($data_dir, $run_id, $config_path, $process_subset,$file_id);


GetOptions (
            'data-dir=s' => \$data_dir,
            'id=s' => \$run_id,
            'config=s' => \$config_path,
            'file-id=s' => \$file_id,
            'process-subset=s' => \$process_subset
        );
print STDERR "$data_dir $run_id $config_path $process_subset\n\n";
my %config = map {m/^([^=]*)="(.*)"$/; $1 => $2} split("\n",`./$config_path list`);

my $input_dir = $config{download_dir};
my $output_dir = $config{html2tei_text};

unless($input_dir){
  print STDERR "no input directory\n";
  exit 1;
}


my @file_list = glob "$data_dir/$input_dir/$run_id/*.htm";
if($process_subset) {
  print STDERR "WARN: prunning processed files: /[^\\/]*${process_subset}[^\\/]*\\.htm/\n";
  @file_list = grep {m/^.*\/[^\/]*${process_subset}[^\/]*\.htm$/} @file_list
}

exit 1 unless @file_list;

`mkdir -p $data_dir/$output_dir/$run_id`;





for my $fileIn (@file_list){
  my ($dY,$dM,$dD,$suff) = $fileIn =~ m/(\d{4})(\d{2})(\d{2})(?:-(\d+))?\.htm$/;
  $suff //= 0;
  print STDERR "$fileIn\n\t$dY-$dM-$dD\t$suff\n";
  my $fileOut = sprintf("%s/%s/%s/%s_%04d-%02d-%02d-m%d.xml",$data_dir,$output_dir,$run_id,$file_id,$dY,$dM,$dD,$suff);
  print STDERR "\t$fileOut\n";
  my $htm = open_html($fileIn);
  my $tei = XML::LibXML::Document->new("1.0", "utf-8");
  my $root_node = XML::LibXML::Element->new('TEI');
  $tei->setDocumentElement($root_node);
  $root_node->setNamespace('http://www.tei-c.org/ns/1.0','',1);
  $root_node->setAttributeNS('http://www.w3.org/XML/1998/namespace','id','TODO--TODO');
  $root_node->addNewChild(undef,'teiHeader');
  my $div = $root_node->addNewChild(undef,'text')->addNewChild(undef,'body')->addNewChild(undef,'div');
  $div->setAttribute('type','debateSection');
  my ($chair,$sitting_date,$doc_proc_state);

  my @p = $htm->findnodes('/html/body/*');
  # processing text header
  # date
  add_note($div,(shift @p)->textContent);
  # title
  while(@p && $p[0] && $p[0]->hasAttribute('align')){
    my $content = (shift @p)->textContent;
    if($content =~ m/.* Верховної Ради України ([^\s]+\s+.\..\.)\s*$/){
      $chair = $1;
      print STDERR "CHAIR: $chair\n";
    }
    add_note($div,$content);
  }
  my $utterance;
  while(my $p = shift @p){
    next unless $p->hasChildNodes();
    my $seg;
    my $is_first = 1;
    if($p->hasAttribute('align')){
      if($p->textContent =~ m/.* Верховної Ради України ([^\s]+\s+.\..\.)\s*$/){
        $chair = $1;
        print STDERR "CHAIR: $chair\n";
      }
      add_note($div,$p->textContent);
      undef $utterance;
      next;
    }


    for my $pchild ($p->nonBlankChildNodes()){
      if(ref $pchild eq 'XML::LibXML::Text'){
        my $content = $pchild->data;
        my ($is_chair) = $content =~ s/^\s*ГОЛОВУЮЧ(?:ИЙ|А)./$chair/;
        if($content =~ m/^\d\d:\d\d:\d\d$/){ # time
          add_time_note($seg // $utterance // $div,$content);
        } elsif($is_first && (my ($speaker,$speech) = $content =~ m/^\s*([\p{Lu}\p{Lt}]+[\p{Lu}\p{Lt} \.]*\.)\s*(.*)/)) {
          while($utterance && (my $last_child = ($utterance->childNodes())[-1])){ # moving non seg nodes after utterance
            unless($last_child->nodeName eq 'seg'){
              $last_child->unbindNode;
              $div->insertAfter($last_child,$utterance);
            } else {
              last;
            }
          }
          print "NEW UTTERANCE: '\n\t$1\n\t$2\n";
          add_note($div,$speaker)->setAttribute('type','speaker');
          $utterance = $div->addNewChild(undef,'u');
          $utterance->setAttribute('who',$speaker);
          $utterance->setAttribute('ana',$is_chair ? '#chair':'#regular');
          if($speech){
            $seg = $utterance->appendTextChild('seg',$speech);
          }
        } else {
          $seg = $utterance->addNewChild(undef,'seg') unless $seg;
          $seg->appendText($pchild)
        }
        undef $is_first;
      } else {
        print STDERR $pchild;
        if($pchild->nodeName eq 'i'){
          add_note($seg // $utterance // $div,$pchild->textContent);
        } else {
          print STDERR "=======?? ",$pchild,"\n";
        }

      }
    }
    undef $seg;
    print STDERR $p;
  }
  print_xml($tei);

}



sub open_html {
  my $file = shift;
  my $params = shift // {};
  my %vars = @_;
  my $doc;
  local $/;
  open FILE, $file;
  binmode ( FILE, ":encoding(WINDOWS-1251)" ); # encoding(WINDOWS-1251) windows1251 utf8
  my $rawxml = <FILE>;
  $rawxml = decode_entities($rawxml);
  close FILE;

  if ((! defined($rawxml)) || $rawxml eq '' ) {
    print " -- empty file $file\n";
  } else {
    my $parser = XML::LibXML->new(load_ext_dtd => 0, clean_namespaces => 1, recover => 2);
    $doc = "";
    print STDERR "convert to UTF-8 !!!";
    eval { $doc = $parser->parse_html_string($rawxml); };
    if ( !$doc ) {
      print " -- invalid XML in $file\n";
      print "$@";

    } else {
      $doc->documentElement->setNamespaceDeclURI(undef, undef);
    }
  }
  return $doc
}



sub add_note {
  my ($context,$text) = @_;
  $text =~ s/^\s*|\s*$//g;
  return unless $text;
  print STDERR "adding note '$text'\n";
  my $note = $context->addNewChild(undef,'note');
  $note->appendText($text);
  return $note;
}


sub add_time_note {
  my ($context,$text) = @_;
  print STDERR "adding time note '$text'\n";
  return $context->appendTextChild('note',"($text)");
}


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