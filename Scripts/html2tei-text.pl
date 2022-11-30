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
my @component_ids;
if($process_subset) {
  print STDERR "WARN: prunning processed files: /[^\\/]*${process_subset}[^\\/]*\\.htm/\n";
  @file_list = grep {m/^.*\/[^\/]*${process_subset}[^\/]*\.htm$/} @file_list
}

exit 1 unless @file_list;

`mkdir -p $data_dir/$output_dir/$run_id`;

my %downloaded_files;
{
  open FILE, "$data_dir/$config{seen_file}";
  while(my $line = <FILE>){
    next unless $line =~ m/^$run_id\t/;
    my ($t,$f,$u) = $line =~ m/\t([^\t]*)\t([^\t]*)\t([^\t\s]*)\n?$/;
    print STDERR "($t,$f,$u)\n";
    $downloaded_files{$f} = [$t,$u];
  }
  close FILE;
}

my $parser = XML::LibXML->new();

for my $fileIn (@file_list){
  my ($dY,$dM,$dD,$suff) = $fileIn =~ m/(\d{4})(\d{2})(\d{2})(?:-(\d+))?\.htm$/;
  my ($fileInName) = $fileIn =~ m/([^\/]*)$/;
  $suff //= 0;
  print STDERR "$fileIn\n\t$dY-$dM-$dD\t$suff\n";
  my $id = sprintf("%s_%04d-%02d-%02d-m%d",$file_id,$dY,$dM,$dD,$suff);
  my $fileOut = sprintf("%s/%s/%s/%s.xml",$data_dir,$output_dir,$run_id,$id);
  print STDERR "\t$fileOut\n";
  push @component_ids, $id;
  my $htm = open_html($fileIn);
  my $tei = XML::LibXML::Document->new("1.0", "utf-8");
  my $root_node = XML::LibXML::Element->new('TEI');
  $tei->setDocumentElement($root_node);
  $root_node->setNamespace('http://www.tei-c.org/ns/1.0','',1);
  $root_node->setAttributeNS('http://www.w3.org/XML/1998/namespace','id',$id);
  my $date = sprintf("%04d-%02d-%02d",$dY,$dM,$dD);
  my ($term,$url) = @{$downloaded_files{$fileInName}//[]};
  print STDERR "TODO: $term and $url\n";
  my $teiHeader = $parser->parse_balanced_chunk(
<<HEADER
<teiHeader>
  <fileDesc>
         <titleStmt>
            <!-- TODO -->
            <meeting ana="#parla.term #parla.uni" n="$term">$term</meeting>
            <!-- TODO -->
         </titleStmt>
         <editionStmt>
            <edition>3.0a</edition>
         </editionStmt>
         <extent>
           <!-- TODO -->
         </extent>
         <publicationStmt>
            <!-- TODO -->
         </publicationStmt>
         <sourceDesc>
            <bibl>
               <!-- TODO -->
               <idno type="URI" subtype="parliament">$url</idno>
               <date when="$date">$date</date>
            </bibl>
         </sourceDesc>
      </fileDesc>
      <encodingDesc>
         <!-- TODO -->
      </encodingDesc>
      <profileDesc>
         <settingDesc>
            <setting>
               <!-- TODO -->
               <date when="$date">$date</date>
            </setting>
         </settingDesc>
         <!-- TODO -->
      </profileDesc>
   </teiHeader>
HEADER
    );

  $root_node->appendChild($teiHeader);
  my $div = $root_node->addNewChild(undef,'text')->addNewChild(undef,'body')->addNewChild(undef,'div');
  $div->setAttribute('type','debateSection');
  my ($chair,$sitting_date,$doc_proc_state);

  my @p = $htm->findnodes('/html/body/text() | /html/body/p | /html/body/div/p ');
  print STDERR "number of paragraphs:",scalar @p,"\n";
  # processing text header
  # date
  add_note($div,(shift @p)->textContent)->setAttribute('type','date');
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
        $chair = normalize_speaker($p_data);
        print STDERR "CHAIR: $chair\n";
      } elsif ($p_category eq 'change_chair_next'){
        print STDERR "chair is next: $p\n";
        # undef $chair; <- there is sometime no chair change, even if the prevous line slightly suggest it
        if($p_data){
          print STDERR "adding temporary chairman role: $p_data\n";
          $chair = normalize_speaker($p_data);
        }
        $chair_is_next = 1;
      }
      undef $chair_is_next if $chair && !($p_category eq 'change_chair_next');
      my $note = add_note($div,$p->textContent);
      $note->setAttribute('type','narrative') if $p_category eq 'change_chair';
      $note->setAttribute('type','narrative') if $p_category eq 'change_chair_next';
      $note->setAttribute('type','comment') if $p_category eq 'process_note';

      #undef $utterance;
      next;
    }
    if($p_category eq 'time_note'){
      # print STDERR $p;
      add_time_note($seg // $utterance // $div,$p->textContent);
      next;
    }
    print STDERR "ERROR: missing chair\n" unless $chair;
    for my $pchild ($p->childNodes()){
      if(ref $pchild eq 'XML::LibXML::Text'){
        my $content = $pchild->data;
        my ($is_chair) = $content =~ m/^\s*ГОЛОВУЮ?Ч(?:ИЙ|А).?/;
        if($is_chair && ! $chair){
          print STDERR "ERROR: missing chair person name\n";die;
        }
        my ($speaker,$speech);
        if($is_first
          && $content !~ m/^\s*[ЄЯ]\.\.*\s*/
          && (($speaker,$speech) = $content =~ m/^\s*(
                             [\p{Lu}\p{Lt}'’]{2,}\  # atleast 2 letters to avoid matching one letter words at the begining of sentence that is followed by abbrevitation
                                              (?:
                                                [\p{Lu}\p{Lt}]\.\ *(?:[\p{Lu}\p{Lt}]\b\.?)? # abbrevitated name
                                                |
                                                (?:\b[\p{Lu}\p{Lt}'’]{2,}\b\ *)+ # full name
                                              )
                             |
                             ГОЛОВУЮ?Ч(?:ИЙ|А)\.?
                             |
                             (?:ГОЛОСИ?\ )?ІЗ\ ЗАЛУ\.
                             )
                             [,…\.\s]*
                             (.*)
                             /x)
          && (my $speaker_status = speaker_status($speaker))
          ) {
          if($speaker_status eq 'interrupting'){
print STDERR "$content:\n\t$speaker\t$speech\n";
            add_interruption($utterance//$div,'vocal','shouting',$content);
          } else {
            $speaker = normalize_speaker($speaker);
            add_note($div,$speaker)->setAttribute('type','speaker');
            $utterance = $div->addNewChild(undef,'u');
            $utterance->setAttribute('who',$is_chair ? $chair : $speaker);
            $utterance->setAttribute('ana',$is_chair ? '#chair':'#regular');
            if($speech){
              $seg = $utterance->appendTextChild('seg',$speech);
            }
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
        } elsif($seg // $utterance){
          if($pchild->textContent !~ m/^\s*$/){
            $seg = $utterance->addNewChild(undef,'seg') unless $seg;
            $seg->appendText($pchild->textContent);
          }
        } else {
          print STDERR "WARN: unknown node outside paragraph:",$pchild," ($fileIn)\n";
        }

      }
    }
    undef $seg;
  }

  normalize_elements_and_spaces($tei->documentElement());
  annotate_notes($tei->documentElement());
  save_xml($tei,$fileOut);
}

print STDERR (scalar @file_list)," files processed\n";


my $teiCorpus = XML::LibXML::Document->new("1.0", "utf-8");
my $corpus_root_node = XML::LibXML::Element->new('teiCorpus');
$teiCorpus->setDocumentElement($corpus_root_node);
$corpus_root_node->setNamespace('http://www.tei-c.org/ns/1.0','',1);
$corpus_root_node->setAttributeNS('http://www.w3.org/XML/1998/namespace','id',$file_id);
$corpus_root_node->addNewChild(undef,'teiHeader');
for my $id (sort @component_ids){
  my $incl = $corpus_root_node->addNewChild(undef,'include');
  $incl->setNamespace('http://www.w3.org/2001/XInclude','xi',1);
  $incl->setAttribute('href',"$id.xml");
}
save_xml($teiCorpus,sprintf("%s/%s/%s/%s.xml",$data_dir,$output_dir,$run_id,$file_id));


sub speaker_status {
  my $text = shift;
  return unless $text;
  my %not_speaker = map {$_=>1} qw/COVID./;
  return if $not_speaker{$text};
  return 'interrupting' if $text =~ m/(?:ЗАЛУ)/;
  return 'MP';
}

sub add_note {
  my ($context,$text) = @_;
  if($context->nodeName() eq 'seg' && $text !~ m/[\p{Lu}\p{Ll}\p{Lt}\d]/){
    $context->appendText($text);
    return;
  }
  $text =~ s/^([\s\.,"…;]*)//;
  my $before = $1;
  $text =~ s/\)([\.,"…\s;]*)$/\)/;
  my $after = $1;
  if($context->nodeName() ne 'seg' and ($before or $after)){
    print STDERR "WARN:context is not <seg> but <",$context->nodeName(),">  removing context: '$before'--NOTE--'$after'\n";
    undef $before;
    undef $after;
  }
  $context->appendText($before) if $before;
  $text =~ s/\s\s+/ /g;
  if($context->nodeName() eq 'seg' and ($text =~ m/^[^\w\d]*$/ or $text =~ m/^[^\w\d]*\w[^\w\d]*$/)){
    $context->appendText($text);
    $context->appendText($after) if $after;
    return;
  }

  my $note;
  $text =~ s/\s*$//;
  $text =~ s/^\s*//;
  if($text){
    $note = $context->addNewChild(undef,'note');
    $note->appendText($text);
  }
  $context->appendText($after) if $after;
  return $note;
}


sub add_time_note {
  my ($context,$text) = @_;
  #print STDERR "adding time note '$text'\n";
  return add_note($context, "($text)")->setAttribute('type','time');
}

sub add_interruption {
  my ($context,$elemName,$type,$text,$attName) = @_;
  my $node = $context->addNewChild(undef,$elemName);
  $node->setAttribute($attName//'type',$type) if $type;
  $node->appendTextChild('desc',$text);
  return $node;
}

sub add_and_annotate_note {
  my ($context,$text) = @_;
  my ($elem,$type,$attName) = annotate_note($text);
  print STDERR "$elem\t",($type//'??'),"\t$text\n";
  return add_interruption($context,$elem,$type,$text,$attName) unless $elem eq 'note';
  my $note = add_note($context,$text);
  $note->setAttribute('type',$type) if $type;
  return $note;
}

sub annotate_note {
  my $text = shift;
  $text =~ s/^\s*\(|\)\s*$//g;
  return qw/note time/ if $text =~ m/^\d{2}:\d{2}:\d{2}$/;
  return qw/vocal shouting/ if $text =~ m/ГОЛОС.? ІЗ ЗАЛУ/i;

  return qw/kinesic applause/ if $text =~ m/Оплески/i;
  return qw/vocal noise/ if $text =~ m/Шум [ув] залі/i;
  return qw/incident action/ if $text =~ m/Хвилина мовчання/i;
  return qw/incident action/ if $text =~ m/Державний Гімн/i;
  return qw/incident action/ if $text =~ m/Лунає Гімн/i;
  return qw/gap inaudible reason/ if $text =~ m/^Не чути$/i;
  return qw/note comment/ if $text =~ m/\bмовою$/i;


  return qw/vocal exclamat/ if $text =~ m/Вигуки/i;

  return 'note';
}

sub annotate_notes {
  my $node = shift;
  print STDERR "TODO: get all notes without annotation and replace them with proper node\n";
  for my $note ($node->findnodes('.//*[local-name() = "note" and not(@type)]')){
    my $text = $note->textContent;
    #$note->removeTextContent;
    my $new_note = add_and_annotate_note($note,$text); # hack -a add it as a child(use it as a context)
    $new_note->unbindNode;
    $note->parentNode->insertAfter($new_note,$note);
    $note->unbindNode;
  }
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
  return 'time_note' if $not_spaced_content =~  m/^\s*(?:\d+-)?\d+ \w+ \d\d\d\d року\s*$/;
  return 'time_note' if $not_spaced_content =~  m/^\s*(?:\d+-)?\d+ ?\w+(?: \d\d\d\d року)?,? \d+(?:[:\.]\s*\d\d)?(?:\s*година)?\s*$/;
  return 'time_note' if $not_spaced_content =~  m/^\s*(?:\d+-)?\d+ ?\w+(?: \d\d\d\d року)?,? \d\d? година? \d\d? хвилин[аи]?\s*$/;

  return @{['change_chair',$1]} if $content =~ m/.* Верховної Ради України \s*([\p{Lu}\p{Lt}'’]+[\p{Lu}\p{Lt} \.]*?)\s*$/;
  return @{['change_chair',$1]} if $content =~ m/^\s*Веде засідання [Гг]олов[аи] [Пп]ідготовчої депутатської групи \s*([\p{Lu}\p{Lt}'’]+[\p{Lu}\p{Lt} \.]*?)\s*$/;
  return @{['change_chair',$1]} if $content =~ m/^\s*Веде засідання \s*([\p{Lu}\p{Lt}'’]+[\p{Lu}\p{Lt} \.]*?)\s*$/;
  return @{['change_chair',$1]} if $content =~ m/^\s*Засідання веде\s+([\p{Lu}\p{Lt}'’]+[\p{Lu}\p{Lt} \.]*?)\s*$/;
  return @{['change_chair',$1]} if $content =~ m/^\s*Засідання веде (?:\w+ ){0,6}\s*([\p{Lu}\p{Lt}'’]+[\p{Lu}\p{Lt} \.]*?)\s*$/;
  return @{['change_chair',$1]} if $chair_is_next && $content =~ m/^\s*([\p{Lu}\p{Lt}'’]+[\p{Lu}\p{Lt} \.]*?)\s*$/;
  return @{['change_chair',$1]} if $chair_is_next && $content =~ m/^\s*Верховної Ради України ([\p{Lu}\p{Lt}'’]+[\p{Lu}\p{Lt} \.]*?)\s*$/;

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

sub normalize_speaker {
  my $text_speaker = shift;
  my $new_speaker = $text_speaker;
  while(
    $new_speaker =~ s/'/’/g
    || $new_speaker =~ s/\b([\p{Lu}\p{Lt}])\b$/$1\./
    || $new_speaker =~ s/\.[\. ]+$/\./
    || $new_speaker =~ s/\s\s/ /
    || $new_speaker =~ s/^\s+|\s+$//g
    || $new_speaker =~ s/^(.\.)(.*)$/$2 $1/
    || $new_speaker =~ s/(.\.) +(.\.)/$1$2/
  ){print STDERR "$new_speaker\t"};
  print STDERR "Normalize speaker '$text_speaker'->'$new_speaker'\n" unless $text_speaker eq $new_speaker ;
  return $new_speaker;
}

sub normalize_elements_and_spaces {
  my $node = shift;
  my %process_order = (
    TEI => [qw/div/],
    div => [qw/u/],
    u => [qw/seg note vocal kinesic incident gap/],
    seg => [qw/note vocal kinesic incident gap/],
    vocal => [qw/desc/],
    kinesic => [qw/desc/],
    incident => [qw/desc/],
    gap => [qw/desc/]
    );
  my %normalize_spaces_and_dots = map {$_ => 1} qw/seg note desc/;
  my %move_note_out = map {$_ => 1} qw/u seg/;
  my %to_be_moved_out = map {$_ => 1} qw/note vocal/;
  my %merge_notes = map {$_ => 1} qw/div u seg/;
  my @skip_nested;
  for my $elName (@{$process_order{$node->nodeName()}}){
    for my $elem ($node->findnodes('.//*[local-name() = "'.$elName.'" and not(ancestor::*[contains(" '.join(' ',@skip_nested).' ", local-name())])]')){
      normalize_elements_and_spaces($elem);
    }
    push @skip_nested, $elName;
  }

  if(defined $merge_notes{$node->nodeName()}){ # merging notes with open ( with following note of the same type (no type!)
    my @chNodes = $node->childNodes();
    while(my $chN = shift @chNodes){
      next if ref $chN eq 'XML::LibXML::Text';
      next unless $chN->nodeName eq 'note';
      next if $chN->hasAttribute('type');
      if($chN->textContent =~ m/^[^\()]*\)/){
        print STDERR "WARN: missing opening '(' in note: '",$chN->textContent,"'\n";
        my $prevSibl = $chN->previousSibling();
        if($prevSibl && ref $prevSibl eq 'XML::LibXML::Text'){
          my $datastr = $prevSibl->getData();
          $datastr =~ s/(\(.*?)//;
          $chN->lastChild->setData($1.$chN->textContent());
          $prevSibl->setData($datastr);
          print STDERR "INFO: note fixed: '",$chN->textContent,"'\n";
        }

      }
      next if $chN->textContent =~ m/\)[^\(]*$/;
      next if $chN->textContent =~ m/^[^\(]*$/;
      if($chN->textContent =~ m/\([^\)]*$/){
        my @toAppend = ();
        while(my $nextChN = shift @chNodes){
          if(ref $nextChN eq 'XML::LibXML::Text' && $nextChN->textContent =~ m/^\s*$/){
            push @toAppend,$nextChN;
          } elsif(ref $nextChN eq 'XML::LibXML::Text' && $nextChN->textContent =~ m/^\w*\)/){ # ending ) is in the same word
            print STDERR "INFO: appending part of following text into note: '",to_string($chN),$nextChN->textContent,"' --> '";
            for my $chA (@toAppend){
              $chN->appendText($chA->textContent);
              $chA->unbindNode;
            }
            my ($closing_note) = $nextChN->textContent() =~ m/^(\w*\))/;
            $chN->appendText($closing_note);
            $nextChN->replaceDataRegEx('^\w*\)','');
            print STDERR to_string($chN),$nextChN->textContent,"'\n";
            @toAppend=();
          } elsif ( $nextChN->nodeName eq 'note' && !$nextChN->hasAttribute('type')){
            if($nextChN->textContent =~ m/^[^\(]*\)/ ){
              push @toAppend,$nextChN;
              print STDERR "INFO: note to be merged: '",to_string($chN),"'";
              for my $chA (@toAppend){
                print STDERR "+'",(
                                    ref $nextChN eq 'XML::LibXML::Text'
                                    ? $nextChN->textContent
                                    : to_string($chN)
                                  ),"'";
                $chN->appendText($chA->textContent);
                $chA->unbindNode;
              }
              print STDERR "\nINFO: merged note: '",to_string($chN),"\n";
              unshift @chNodes, $chN;
              @toAppend=();
              last;
            } else {
              push @toAppend,$nextChN;
            }
          } else {
            last;
          }
        }
      }
    }
  }

  if(defined $normalize_spaces_and_dots{$node->nodeName()}){ # normalize dots
    my @chNodes = $node->childNodes();
    for my $ch (0..$#chNodes){
      if(ref $chNodes[$ch] eq 'XML::LibXML::Text'){
        $chNodes[$ch]->replaceDataRegEx('[\.…][\.…]*(\s?)[\s\.…]*','.$1', 'sg');
      }
    }
  }
  while(defined $move_note_out{$node->nodeName()} && (my $last_child = ($node->childNodes())[-1])){ # moving non text/seg nodes after seg/utterance
    if(ref $last_child ne 'XML::LibXML::Text' && $to_be_moved_out{$last_child->nodeName()}){
      $last_child->unbindNode;
      $node->parentNode()->insertAfter($last_child,$node);
    } elsif(ref $last_child eq 'XML::LibXML::Text' && $last_child->textContent() =~ m/^\s*$/) {
      $last_child->unbindNode;
    } else {
      last;
    }
  }

  if(defined $normalize_spaces_and_dots{$node->nodeName()}){ # normalize spaces
    my @chNodes = $node->childNodes();
    for my $ch (0..$#chNodes){
      if(ref $chNodes[$ch] eq 'XML::LibXML::Text'){
        $chNodes[$ch]->replaceDataRegEx('^\s*','') if $ch == 0;
        $chNodes[$ch]->replaceDataRegEx('\s*$','') if $ch == $#chNodes;
        $chNodes[$ch]->replaceDataRegEx('[\.…][\.…]*(\s?)[\s\.…]*','.$1', 'sg');
        $chNodes[$ch]->replaceDataRegEx('\s\s*',' ', 'sg');
        $chNodes[$ch]->replaceDataRegEx('\(\s\s*','(', 'sg');
        $chNodes[$ch]->replaceDataRegEx('\s*\s\)',')', 'sg');
      }
    }
  }
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