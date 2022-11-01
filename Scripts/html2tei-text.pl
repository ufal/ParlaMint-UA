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

use File::Basename;
use File::Path;

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

  my @p = $htm->findnodes('/html/body/text() | /html/body/p | /html/body/div/p ');
  print STDERR "number of paragraphs:",scalar @p,"\n";
  # processing text header
  # date
  add_note($div,(shift @p)->textContent);
  # title
=x
  while(@p && $p[0] && $p[0]->hasAttribute('align')){
    my $content = (shift @p)->textContent;
    if($content =~ m/.* Верховної Ради України ([^\s]+\s+.\..\.)\s*$/){
      $chair = $1;
      print STDERR "CHAIR: $chair\n";
    }
    add_note($div,$content);
  }
=cut
  my $utterance;
  my $chair_is_next;
  while(my $p = shift @p){
    next unless $p->hasChildNodes();
    my $seg;
    my $is_first = 1;
    my ($p_category, $p_data) = get_p_category($p,$chair_is_next);
    # print STDERR "P CATEGORY: $p_category $p\n";
    next if $p_category eq 'empty';
    if($p_category eq 'process_note' || $p_category eq 'change_chair' || $p_category eq 'change_chair_next'){
      if($p_category eq 'change_chair' && $p_data){
        $chair = $p_data;
        print STDERR "CHAIR: $chair\n";
      } elsif ($p_category eq 'change_chair_next'){
        print STDERR "chair is next: $p\n";
        # undef $chair; <- there is sometime no chair change, even if the prevous line slightly suggest it
        if($p_data){
          print STDERR "adding temporary chairman role: $p_data\n";
          $chair = $p_data;
        }
        $chair_is_next = 1;
      }
      undef $chair_is_next if $chair && !($p_category eq 'change_chair_next');
      add_note($div,$p->textContent);
      #undef $utterance;
      next;
    }
    if($p_category eq 'time_note'){
      # print STDERR $p;
      add_time_note($seg // $utterance // $div,$p->textContent);
      next;
    }
    print STDERR "ERROR: missing chair\n" unless $chair;
    for my $pchild ($p->nonBlankChildNodes()){
      if(ref $pchild eq 'XML::LibXML::Text'){
        my $content = $pchild->data;
        my ($is_chair) = $content =~ m/^\s*ГОЛОВУЮЧ(?:ИЙ|А).?/;
        if($is_chair && ! $chair){
          print STDERR "ERROR: missing chair person name\n";die;
        }
        if($is_first
          && $content !~ m/^\s*[ЄЯ]\.\.*\s*/
          && (my ($speaker,$speech) = $content =~ m/^\s*([\p{Lu}\p{Lt}]+[\p{Lu}\p{Lt} \.]{2,}\.|ГОЛОВУЮЧ(?:ИЙ|А).?)\.*\s*(.*)/)
          ) {
          while($utterance && (my $last_child = ($utterance->childNodes())[-1])){ # moving non seg nodes after utterance
            unless($last_child->nodeName eq 'seg'){
              $last_child->unbindNode;
              $div->insertAfter($last_child,$utterance);
            } else {
              last;
            }
          }
          print STDERR "NEW UTTERANCE:\t$speaker\t$fileIn\n";
          add_note($div,$speaker)->setAttribute('type','speaker');
          $utterance = $div->addNewChild(undef,'u');
          $utterance->setAttribute('who',$is_chair ? $chair : $speaker);
          $utterance->setAttribute('ana',$is_chair ? '#chair':'#regular');
          if($speech){
            $seg = $utterance->appendTextChild('seg',$speech);
          }
        } elsif($content !~ m/^\s*$/) {
          unless($utterance){
            #print_xml($tei);
            print  "NO ACTIVE UTTERANCE!!! appeared in: $fileIn\n";
            print STDERR "Trying to add '$pchild'\n";
          }
          $seg = $utterance->addNewChild(undef,'seg') unless $seg;
          $seg->appendText($pchild);
        }
        undef $is_first;
      } else {
        if($pchild->nodeName eq 'i'){
          add_note($seg // $utterance // $div,$pchild->textContent);
        } else {
          print STDERR "WARN: unknown node:",$pchild," ($fileIn)\n";
        }

      }
    }
    while($seg && (my $last_child = ($seg->childNodes())[-1])){ # moving non seg nodes after utterance
      unless(ref $last_child eq 'XML::LibXML::Text'){
        $last_child->unbindNode;
        $utterance->insertAfter($last_child,$seg);
      } else {
        $last_child->replaceDataRegEx('\s*$','');
        last;
      }
    }
    undef $seg;
  }

  while($utterance && (my $last_child = ($utterance->childNodes())[-1])){ # moving non seg nodes after utterance
    unless($last_child->nodeName eq 'seg'){
      $last_child->unbindNode;
        $div->insertAfter($last_child,$utterance);
    } else {
      last;
    }
  }
  save_xml($tei,$fileOut);

}

print STDERR (scalar @file_list)," files processed\n";





sub add_note {
  my ($context,$text) = @_;
  $text =~ s/^\s*|\s*$//g;
  $text =~ s/\s\s+/ /g;
  if($text =~ m/^[^\w\d]*$/ or $text =~ m/^[^\w\d]*\w[^\w\d]*$/){
    $context->appendText($text);
    return;
  }

  return unless $text;
  #print STDERR "adding note '$text'\n";
  my $note = $context->addNewChild(undef,'note');
  $note->appendText($text);
  return $note;
}


sub add_time_note {
  my ($context,$text) = @_;
  #print STDERR "adding time note '$text'\n";
  return add_note($context, "($text)")->setAttribute('type','time');
}


sub get_p_category {
  my $node = shift;
  my $chair_is_next = shift;
  return 'empty' unless $node;
  return 'process_note' if ref $node eq 'XML::LibXML::Text';
  my @childnodes = $node->childNodes();
  my $content = $node->textContent;
  my $not_spaced_content = $content;
  $not_spaced_content =~ s/(\d+\s+)/$1 /g;
  $not_spaced_content =~ s/(\s+\d+)/ $1/g;
  $not_spaced_content =~ s/\b\s\b//g;
  $not_spaced_content =~ s/\s+/ /g;
  $not_spaced_content =~ s/^\s*|\s*$//g;

  $content =~ s/\s+/ /g;

  return 'empty' if $not_spaced_content eq '';
  return 'time_note' if $not_spaced_content =~  m/^\(?\s*\d+ година\.\s*\)?$/;
  return 'time_note' if $not_spaced_content =~  m/^\d\d:\d\d:\d\d$/;
  return 'time_note' if $not_spaced_content =~  m/^\s*\d+ \w+ \d\d\d\d року, \d+(?:[:\.]\s*\d\d)? година\s*$/;

  return @{['change_chair',$1]} if $content =~ m/.* Верховної Ради України \s*([\p{Lu}\p{Lt}]+[\p{Lu}\p{Lt} \.]*?)\s*$/;
  return @{['change_chair',$1]} if $content =~ m/^\s*Веде засідання [Гг]олов[аи] [Пп]ідготовчої депутатської групи \s*([\p{Lu}\p{Lt}]+[\p{Lu}\p{Lt} \.]*?)\s*$/;
  return @{['change_chair',$1]} if $content =~ m/^\s*Веде засідання \s*([\p{Lu}\p{Lt}]+[\p{Lu}\p{Lt} \.]*?)\s*$/;
  return @{['change_chair',$1]} if $content =~ m/^\s*Засідання веде (?:\w+ ){0,6}\s*([\p{Lu}\p{Lt}]+[\p{Lu}\p{Lt} \.]*?)\s*$/;
  return @{['change_chair',$1]} if $chair_is_next && $content =~ m/^\s*([\p{Lu}\p{Lt}]+[\p{Lu}\p{Lt} \.]*?)\s*$/;
  return @{['change_chair',$1]} if $chair_is_next && $content =~ m/^\s*Верховної Ради України ([\p{Lu}\p{Lt}]+[\p{Lu}\p{Lt} \.]*?)\s*$/;

  # return 'speech' if @childnodes > 1; # not working - other content appears even in notes

  return 'process_note' if $content =~ m/^\s*(?:|ПОЗАЧЕРГОВЕ|УРОЧИСТЕ)?\s*ЗАСІДАННЯ/;
  return 'process_note' if $content =~ m/^\s*ЗАСІДАННЯ /;
  return 'process_note' if $content =~ m/^\s*(?:Сесійна зала|Сесійний зал) Верховної Ради України\s*$/;

  return @{['change_chair_next',$1]} if $content =~ m/^\s*Веде засідання ((?:\w+ ){0,3}[Гг]олов[аи]) Верховної Ради України\s*$/;
  return @{['change_chair_next',$1]} if $content =~ m/^\s*Веде засідання ((?:\w+ ){0,3}[Гг]олов[аи])\s*$/;
  return 'process_note' if $content =~ m/\d+\s+\w+\s+\d+\s+року,\s+\d+\s+година/;

  return 'process_note' if $not_spaced_content =~  m/Сесійний зал Верховної Ради$/;
  return 'process_note' if $not_spaced_content =~  m/^України\. \d+ \w+ \d\d\d\d року\.$/;
  return 'process_note' if $content =~  m/(?: .){5}/ && $content !~  m/\w{5}/; # spaced text detection (contains spaced word len>5 and donesnt contain nonspaced)

  return 'process_note' if $node->hasAttribute('align') && $node->getAttribute('align') eq 'center';
  return 'unknown';
}






################################################
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
  my $dir = dirname($filename);
  File::Path::mkpath($dir) unless -d $dir;
  open FILE, ">$filename";
  binmode FILE;
  my $raw = to_string($doc);
  print FILE $raw;
  close FILE;
}