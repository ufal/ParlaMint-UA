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

my ($data_dir, $run_id, $config_path, $process_subset,$file_id, $subdir_by_year);


my $tz = 'Europe/Prague';
my $strp = DateTime::Format::Strptime->new(
  pattern   => '%Y-%m-%e %H:%M:%S',
);

GetOptions (
            'data-dir=s' => \$data_dir,
            'id=s' => \$run_id,
            'config=s' => \$config_path,
            'file-id=s' => \$file_id,
            'process-subset=s' => \$process_subset,
            'subdir-by-year' => \$subdir_by_year,
        );
print STDERR "$data_dir $run_id $config_path $process_subset\n\n";
my %config = map {m/^([^=]*)="(.*)"$/; $1 => $2} split("\n",`./$config_path list`);

my $input_dir = $config{download_dir};
my $output_dir = $config{html2tei_text};

unless($input_dir){
  print STDERR "no input directory\n";
  exit 1;
}

my $speaker_name_re = qr/
[\p{Lu}\p{Lt}][-\p{Lu}\p{Lt}'’`]{2,}\.?\s+ # atleast 2 letters to avoid matching one letter words at the begining of sentence that is followed by abbrevitation
(?:
  [\p{Lu}\p{Lt}]\.\s*(?:[\p{Lu}\p{Lt}]\b\.?)? # abbrevitated name
  |
  (?:\b[\p{Lu}\p{Lt}'’]{2,}\b\s*)+ # full name
)/x;
my $chairman_re = qr/(?:(?:\S?[Г\S]?[ГОЛ]?[ОЛO]?[ЛОB]?[OВУ]{1,3}[ВУЮ]?О?[УЮЧ]? ?[ЮЧ]?(?:[ИЙ]{1,2}|А))(?<=\S{7})\.?|ГОЛОВ[АУ]\b\.?|ГОЛОВУЮЧІЙ\b\.?)/; # some character can miss, but minimum is 7


my @file_list = glob "$data_dir/$input_dir/$run_id/*.htm";
my @component_files;
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
    my ($t,$s,$mt,$f,$u) = $line =~ m/\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t\s]*)\n?$/;
    print STDERR "($t,$s,$mt,$u)\n";
    $downloaded_files{$f} = [$t,$s,$mt,$u];
  }
  close FILE;
}

my $parser = XML::LibXML->new();

for my $fileIn (@file_list){
  my ($dY,$dM,$dD,$suff) = $fileIn =~ m/(\d{4})(\d{2})(\d{2})(?:-(\d+))?\.htm$/;
  my $subdir = '';
  if($subdir_by_year){
    $subdir = "$dY/";
    `mkdir -p $data_dir/$output_dir/$run_id/$subdir`;
  }
  my ($fileInName) = $fileIn =~ m/([^\/]*)$/;
  # unless($fileInName =~ m/20181002.htm/){print STDERR "DEBUG: skipping $fileInName\n"; next;}
  $suff //= 0;
  print STDERR "INFO: processing $fileIn\t($dY-$dM-$dD\t$suff)\n";
  my $id = sprintf("%s_%04d-%02d-%02d-m%d",$file_id,$dY,$dM,$dD,$suff);
  my $fileOut = sprintf("%s/%s/%s/%s%s.xml",$data_dir,$output_dir,$run_id,$subdir,$id);
  push @component_files, "$subdir$id.xml";
  my $date = sprintf("%04d-%02d-%02d",$dY,$dM,$dD);
  my ($term,$session,$meeting_type,$url) = @{$downloaded_files{$fileInName}//[]};
  my $htm = open_html($fileIn);
  $htm = fix_html($htm,$date,$term);
  my $tei = XML::LibXML::Document->new("1.0", "utf-8");
  my $root_node = XML::LibXML::Element->new('TEI');
  $tei->setDocumentElement($root_node);
  $root_node->setNamespace('http://www.tei-c.org/ns/1.0','',1);
  $root_node->setAttributeNS('http://www.w3.org/XML/1998/namespace','id',$id);
  $root_node->setAttributeNS('http://www.w3.org/XML/1998/namespace','lang','uk');
  print STDERR "TODO: $term and $url\n";
  my $teiHeader = $parser->parse_balanced_chunk(
<<HEADER
<teiHeader>
  <fileDesc>
         <titleStmt>
            <!-- TODO -->
            <meeting ana="#parla.term #parla.uni" n="$term">$term</meeting>
            <meeting ana="#parla.session #parla.uni" n="$session">$session</meeting>
            <!-- TODO: meeting type: $meeting_type -->
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
  my @p = $htm->findnodes('/html/body/text() | /html/body/p | /html/body//div/p ');
  my @unexpected_content = $htm->findnodes('/html/body/*[not(name()="p")][not(name()="div")] ');
  print STDERR "INFO: number of paragraphs:",scalar @p,"\n";
  print STDERR "ERROR: unexpected content: nodename=",join(' nodename=', map {$_->nodeName()} (@unexpected_content)),"\n" if @unexpected_content;
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
  my $prev_nonchair_alias;
  my $prev_nonchair_surname = 'NEVER_MATCHING_CONTENT';
  my $empty_par_before = 1;
  while(my $p = shift @p){
    next unless $p->hasChildNodes();

    #prune paragraph from invisible nodes (nodes without text content) and merge adjected text content
    for my $nocontent_node ($p->findnodes('.//*[not(text())]')){
      if(
        ref $nocontent_node->previousSibling() eq 'XML::LibXML::Text'
        and
        ref $nocontent_node->nextSibling() eq 'XML::LibXML::Text'
        ){
        $nocontent_node->previousSibling()->appendData($nocontent_node->nextSibling()->data);
        $nocontent_node->nextSibling()->unbindNode;
      }
      $nocontent_node->unbindNode
    }
    my $no_change_in_loop;
    do {
      $no_change_in_loop = 1;
      my ($node) = $p->findnodes('.//*[not(name()="i") and not(./*)]');
      if($node){
        undef $no_change_in_loop;
        my $parent = $node->parentNode;
        my $prev = $node->previousSibling();
        my $next = $node->nextSibling();
        if($prev && ref $prev eq 'XML::LibXML::Text'){
          $prev->appendData($node->textContent);
          $node->unbindNode;
          # $node = $prev;
        } else {
          $prev = XML::LibXML::Text->new($node->textContent);
          $parent->replaceChild( $prev, $node );
        }

        if($next && ref $next eq 'XML::LibXML::Text'){
          $prev->appendData($next->data);
          $next->unbindNode;
        }
      }
    } until($no_change_in_loop);
    my $seg;
    my $is_first = 1;
    my ($p_category, $p_data) = get_p_category($p,$chair_is_next);
    # print STDERR "P CATEGORY: $p_category $p\n";
    if($p_category eq 'empty'){
      $empty_par_before = 1;
      next;
    }
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
      add_time_note($seg // $utterance // $div,trim($p->textContent), $date);
      next;
    }
    print STDERR "ERROR: missing chair\n" unless $chair;
    # print STDERR "DEBUG: $p\n" if $empty_par_before;
    for my $pchild ($p->childNodes()){
      if(ref $pchild eq 'XML::LibXML::Text'){
        my $content = $pchild->data;
        my $is_chair = $content =~ m/^\s*$chairman_re/;
        if($is_chair && ! $chair){
          print STDERR "ERROR: missing chair person name\n";
        }
        my ($speaker,$speech);

        my $speaker_re = $is_chair
              ? $chairman_re
              : qr/$speaker_name_re
                   |
                   (?:ГОЛОСИ?\s+)?(?:І?З|В)\s+ЗАЛ[ИУІ]\.
                   |
                   $prev_nonchair_surname
                   /x;
        my $only_forename_re = ($is_chair || ! $empty_par_before)
              ? qr/NEVER_MATCHING_CONTENT/
              : qr/[\p{Lu}\p{Lt}][-\p{Lu}\p{Lt}'’`]{2,}\s*(?:\.|\([\p{Lu}\p{Lt}][-\p{Lu}\p{Lt}'’`]{2,}\))/x;
         if($is_first
          && $content !~ m/^\s*[ЄЯ]\.\.*\s*/
          && (($speaker,$speech) = $content =~ m/^\s*(
                             $speaker_re
                             |
                             $only_forename_re
                             )
                             [,…\.\s]*
                             (.*)
                             /x)
          && (my $speaker_status = speaker_status($speaker))
          ) {
          if($speaker_status eq 'interrupting'){
#print STDERR "$content:\n\t$speaker\t$speech\n";
            add_interruption($utterance//$div,'vocal','shouting',$content);
          } else {
            $speaker = normalize_speaker($speaker);
            add_note($div,$speaker)->setAttribute('type','speaker');
            $utterance = $div->addNewChild(undef,'u');
            $speaker = $prev_nonchair_alias if $speaker eq $prev_nonchair_surname; # interrupted utterance continue
            $utterance->setAttribute('who',$is_chair ? $chair : normalize_speaker_who($speaker));
            $utterance->setAttribute('ana',$is_chair ? '#chair':'#regular');
            undef $empty_par_before;
            if($speech){
              $seg = $utterance->addNewChild(undef,'seg');
              $seg->appendText($speech);
              # $seg = $utterance->appendTextChild('seg',$speech);
            }
            unless($is_chair){
              $prev_nonchair_alias = $speaker;
              # TODO: improve
              if($speaker =~ m/^([\p{Lu}\p{Lt}][-\p{Lu}\p{Lt}'’`]{2,}).?$/){ # take last name
                $prev_nonchair_surname = $1;
              } else {
                ($prev_nonchair_surname) = $speaker =~ m/^([^ ]{3,})/;
              }
            }
          }
        } elsif($content !~ m/^\s*$/) {
          unless($utterance){
            # print_xml($tei);
            print STDERR "ERROR: NO ACTIVE UTTERANCE!!! appeared in: $fileIn\n";
            print STDERR "WARN: adding '$pchild' as a none\n";
            add_note($div,$pchild); # this shouldnt happen !!!
          } else {
            $seg = $utterance->addNewChild(undef,'seg') unless $seg;
            $seg->appendText($pchild);
          }
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
  normalize_characters_in_text($tei->documentElement());
  annotate_notes($tei->documentElement());
  move_inaudible_inside_utterance($tei->documentElement());
  remove_empty($tei->documentElement(),'seg');
  remove_empty($tei->documentElement(),'u');
  add_ids($tei->documentElement(),$id,['u','u'],['seg','p']);
  save_xml($tei,$fileOut);
  print STDERR "INFO: saved to $fileOut\n";
}

print STDERR (scalar @file_list)," files processed\n";


my $teiCorpus = XML::LibXML::Document->new("1.0", "utf-8");
my $corpus_root_node = XML::LibXML::Element->new('teiCorpus');
$teiCorpus->setDocumentElement($corpus_root_node);
$corpus_root_node->setNamespace('http://www.tei-c.org/ns/1.0','',1);
$corpus_root_node->setAttributeNS('http://www.w3.org/XML/1998/namespace','id',$file_id);
$corpus_root_node->setAttributeNS('http://www.w3.org/XML/1998/namespace','lang','uk');
$corpus_root_node->addNewChild(undef,'teiHeader');
for my $component_file (sort @component_files){
  my $incl = $corpus_root_node->addNewChild(undef,'include');
  $incl->setNamespace('http://www.w3.org/2001/XInclude','xi',1);
  $incl->setAttribute('href',$component_file);
}
save_xml($teiCorpus,sprintf("%s/%s/%s/%s.xml",$data_dir,$output_dir,$run_id,$file_id));


sub speaker_status {
  my $text = shift;
  return unless $text;
  my %not_speaker = map {$_=>1} qw/COVID./;
  return if $not_speaker{$text};
  return 'interrupting' if $text =~ m/(?:ЗАЛУ)/;
  return 'interrupting' if $text =~ m/(?:ГОЛОС.*ЗАЛ[ИУІ])/;
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
  my ($context,$text, $date) = @_;
  #print STDERR "adding time note '$text'\n";
  my $note;
  my $datetime;
  if($text =~ m/^\d\d:\d\d:\d\d$/ && eval {$datetime = $strp->parse_datetime("$date $text")}){
    $note = $context->addNewChild(undef,'note');
    $note->appendTextChild('time',$text);
    $note->firstChild->setAttribute('when',$datetime)
  }  else {
    $note = add_note($context, "$text");
  }
  return $note->setAttribute('type','time');
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
#  print STDERR "$elem\t",($type//'??'),"\t$text\n";
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
  return qw/gap inaudible reason/ if $text =~ m/^нерозбірливо$/i;
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

sub add_ids {
  my $node = shift;
  my $id = shift;
  my ($elemName,$pref) = @{shift//[]};
  return unless $elemName;
  my @nodes = $node->findnodes('.//*[local-name() = "'.$elemName.'"]');
  for my $i (0..$#nodes){
    my $new_id = sprintf("%s.%s%d",$id,$pref,$i+1);
    $nodes[$i]->setAttributeNS('http://www.w3.org/XML/1998/namespace','id',$new_id);
    add_ids($nodes[$i],$new_id,@_);
  }
}

sub remove_empty {
  my $node = shift;
  my $elemName=shift;
  return unless $elemName;
  for my $nd ($node->findnodes('.//*[local-name() = "'.$elemName.'" and not(normalize-space(text())) and not(./*)]')){
    $nd->unbindNode;
  }
}

sub move_inaudible_inside_utterance {
  my $node = shift;
  for my $gap ($node->findnodes('.//*[local-name() = "gap" and @reason="inaudible"]')){
    my $prevSibl = $gap->previousSibling;
    if($prevSibl && ref $prevSibl eq 'XML::LibXML::Element' && $prevSibl->nodeName eq 'u'){
      $gap->unbindNode;
      $prevSibl->appendChild($gap);
    }
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
  return 'time_note' if $not_spaced_content =~  m/^\s*(?:\d+-)?\d+ ?\w+(?: \d\d\d\d року)?,? \d+(?:[:\.]\s*\d\d)?(?:\s*год(?:ина|\.))?\s*$/;
  return 'time_note' if $not_spaced_content =~  m/^\s*(?:\d+-)?\d+ ?\w+(?: \d\d\d\d року)?,? \d\d? година? \d\d? хвилин[аи]?\s*$/;

  return @{['change_chair',$1]} if $content =~ m/.* Верховної Ради України \s*([\p{Lu}\p{Lt}'’]+[\p{Lu}\p{Lt} \.]*?)\s*$/;
  return @{['change_chair',$1]} if $content =~ m/^\s*Веде засідання [Гг]олов[аи] [Пп]ідготовчої депутатської групи \s*([\p{Lu}\p{Lt}'’]+[\p{Lu}\p{Lt} \.]*?)\s*$/;
  return @{['change_chair',$1]} if $content =~ m/^\s*Веде засідання \s*([\p{Lu}\p{Lt}'’]+[\p{Lu}\p{Lt} \.]*?)\s*$/;
  return @{['change_chair',$1]} if $content =~ m/^\s*Засідання веде\s+([\p{Lu}\p{Lt}'’]+[\p{Lu}\p{Lt} \.]*?)\s*$/;
  return @{['change_chair',$1]} if $content =~ m/^\s*Засідання веде (?:\w+ ){0,6}\s*([\p{Lu}\p{Lt}'’]+[\p{Lu}\p{Lt} \.]*?)\s*$/;
  return @{['change_chair',$1]} if $chair_is_next && $content =~ m/^\s*(?:(?:(?:Верховної )?Ради )?України )?([\p{Lu}\p{Lt}'’]+[\p{Lu}\p{Lt} \.]*?)\s*$/;
  return @{['change_chair',uc $1]} if $content =~ m/.* Верховної Ради України \s*([\p{Lu}\p{Lt}'’][\p{L}'’]+ (?:[\p{Lu}\p{Lt}]\. ?){1,2})\s*$/;

  # return 'speech' if @childnodes > 1; # not working - other content appears even in notes

  return 'process_note' if $content =~ m/^\s*(?:|ПОЗАЧЕРГОВЕ|УРОЧИСТЕ)?\s*ЗАСІДАННЯ/;
  return 'process_note' if $content =~ m/^\s*ЗАСІДАННЯ /;
  return 'process_note' if $content =~ m/^\s*(?:Сесійна зала|Сесійний зал) Верховної Ради України\s*$/;

  return @{['change_chair_next',$1]} if $content =~ m/^\s*Веде засідання ((?:[\p{L}'’]+\s){0,3}[Гг]олов[аи])(?: Верховної(?: Ради(?: України)?)?)?\s*$/;
  return 'process_note' if $content =~ m/\d+\s+\w+\s+\d+\s+року,\s+\d+\s+година/;

  return 'process_note' if $not_spaced_content =~  m/Сесійний зал Верховної Ради$/;
  return 'process_note' if $not_spaced_content =~  m/^України\. \d+ \p{Lt}+ \d\d\d\d року\.$/;
  return 'process_note' if $content =~  m/(?: .){5}/ && $content !~  m/[\p{L}'’]{5}/; # spaced text detection (contains spaced word len>5 and donesnt contain nonspaced)

  return 'process_note' if $not_spaced_content =~ m/(?:ПІСЛЯ )?ПЕРЕРВИ/; # (after )break

  return 'process_note' if $node->hasAttribute('align') && $node->getAttribute('align') eq 'center';
  return 'unknown';
}






################################################

sub trim {
  my $text = shift;
  $text =~ s/^\s*|\s*$//g;
  $text =~ s/\s+/ /g;
  return $text;
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

sub fix_html {
  my ($html,$date,$term) = @_;
  fix_html_replace_pre($_) for $html->findnodes('//pre');
  if($term < 7){
    fix_html_notes_in_p($_) for $html->findnodes('//p[not(*) and text()]');
  }
  return $html
}

sub fix_html_replace_pre {
  my $pre = shift;
  my $nodePlaceholder = $pre;
  for my $chNode ($pre->childNodes){
    for my $node (fix_html_to_p($chNode)){
      if( $nodePlaceholder->hasAttribute('align')
          && $node->textContent =~ /^(України|скликання).*/
          && $nodePlaceholder->textContent =~ /^Веде/){ # append to previous node
        $nodePlaceholder->appendText(' '.$node->textContent);

      } else {
        $pre->parentNode->insertAfter($node,$nodePlaceholder);
        $nodePlaceholder = $node;
      }
    }
  }
  $pre->unbindNode;
}

sub fix_html_to_p {
  my $node = shift;
  my $type = shift//'';
  my @nodes = ();
  if(ref $node eq 'XML::LibXML::Text'){
    for my $line (split /\n\n/,$node->textContent){
      my ($spaces) = $line =~ s/^(\s*)//;
      $line =~ s/\s\s*/ /g; # normelize spaces
      $line =~ s/^\s*---*\s*$//; # remove divider ----
      if($line){
        my $p = XML::LibXML::Element->new('p');
        $p->appendText($line);
        if(length($spaces) > 5 or $type =~ m/[bi]/){
          $p->setAttribute('align','center');
        }
        push @nodes,$p;
      }
    }
  } else {
    for my $n ($node ->childNodes){
      push @nodes, fix_html_to_p($n,$node->nodeName);
    }
  }
  return @nodes;
}

sub fix_html_notes_in_p {
  my $p = shift;
  my $text = $p->textContent;
  $_->unbindNode for $p->childNodes();;
  fix_html_insert_into_p($p,$text,0);
}

sub fix_html_insert_into_p {
  my ($p,$text,$DEBUG) = @_;
  return unless $text;
  if($text =~ s/^([^(]+)//){
    $p->appendText($1);
  } elsif ($text =~ s/^(\([^()]+\))//){
    my $i = XML::LibXML::Element->new('i');
    $i->appendText($1);
    $p->appendChild($i);
  } else {
    $p->appendText($text);
    $text = '';
  }
  fix_html_insert_into_p($p,$text,$DEBUG+1);
}

sub normalize_speaker {
  my $text_speaker = shift;
  my $new_speaker = $text_speaker;
  while(
    $new_speaker =~ s/['`]/’/g
    || $new_speaker =~ s/\s+\./\./
    || $new_speaker =~ s/\b([\p{Lu}\p{Lt}])\b$/$1\./
    || $new_speaker =~ s/^\b([\p{Lu}\p{Lt}]{2,})\. /$1 /
    || $new_speaker =~ s/\.[\. ]+$/\./
    || $new_speaker =~ s/\s\s/ /
    || $new_speaker =~ s/^\s+|\s+$//g
    || $new_speaker =~ s/^(.\.)(.*)$/$2 $1/
    || $new_speaker =~ s/(.\.) +(.\.)/$1$2/
  ){print STDERR "$new_speaker\t"};
  print STDERR "Normalize speaker '$text_speaker'->'$new_speaker'\n" unless $text_speaker eq $new_speaker ;
  return $new_speaker;
}

sub normalize_speaker_who {
  my $text_speaker = shift;
  my $new_speaker = $text_speaker;
  $new_speaker =~ s/\s*[(]/ /g;
  $new_speaker =~ s/[)]\s*/ /g;
  $new_speaker =~ s/^\s*|\s*$//g;
  print STDERR "Normalize speaker who '$text_speaker'->'$new_speaker'\n" unless $text_speaker eq $new_speaker ;
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
      next if grep {ref $_ eq 'XML::LibXML::Element'} $chN->childNodes;
      {
        my $str = $chN->textContent;
        $str =~ s/\s+/ /g;
        $chN->lastChild->setData($str);
      }
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
    my @chNodes = grep {ref $_ eq 'XML::LibXML::Text'} $node->childNodes();
    for my $ch (0..$#chNodes){
      $chNodes[$ch]->replaceDataRegEx('[\.…][\.…]*(\s?)[\s\.…]*','.$1', 'sg');
      if($ch > 0 && $chNodes[$ch-1] =~ m/[,!\.;]\s*$/){
        $chNodes[$ch]->replaceDataRegEx('^[\s\.!;,]*?(\s?)[\.\s!;,]*','$1');
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
        #TODO add spaces around notes, if seg!!!
        if($node->nodeName() eq 'seg'){
          $chNodes[$ch]->replaceDataRegEx('$',' ') if $ch < $#chNodes;
          $chNodes[$ch]->replaceDataRegEx('^([^\.\?!;,])',' $1') if $ch > 0;
        }
        $chNodes[$ch]->replaceDataRegEx('\s*[\.…][\.…]*(\s?)[\s\.…]*','.$1', 'sg');
        $chNodes[$ch]->replaceDataRegEx('\s\s*',' ', 'sg');
        $chNodes[$ch]->replaceDataRegEx('\(\s\s*','(', 'sg');
        $chNodes[$ch]->replaceDataRegEx('\s*\s\)',')', 'sg');
      }
    }
  }
}

sub normalize_characters_in_text {
  my $node = shift;
  my @textNodes = $node->findnodes('.//*[local-name() = "text"]//text()');
  for my $t (@textNodes){
    $t->replaceDataRegEx('&amp;(amp;)*','&','sg');
    $t->replaceDataRegEx("['`]","’",'sg');
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