#!/usr/bin/env perl

use warnings;
use strict;
use open qw(:std :utf8);
use utf8;
use Getopt::Long qw(:config debug);
use XML::LibXML;
use XML::LibXML::PrettyPrint;
use Encode qw(decode encode);


use File::Basename;
use File::Path;

use Lingua::Identify::Any qw/detect_text_language/;
use Data::Dumper;
my ($data_dir, $run_id, $config_path,$lang_stats,@langs);

my $lang_translations = {};

my @uk_words = qw/
врахувати
давайте
добре
дякую
завершуйте
продовжуйте
прошу
секунд
спасибо
хвилину
яка
яке
яку
/;
my $uk_words = join('|',@uk_words);

GetOptions (
            'data-dir=s' => \$data_dir,
            'id=s' => \$run_id,
            'config=s' => \$config_path,
            'lang=s' => \@langs,
            'speaker-lang-stats' => \$lang_stats
        );
my %config = map {m/^([^=]*)="(.*)"$/; $1 => $2} grep{m/^([^=]*)="(.*)"$/} split("\n",`./$config_path list`);

my $input_dir = $config{html2tei_text};
my $output_dir = $config{tei_lang};

unless($input_dir){
  print STDERR "no input directory\n";
  exit 1;
}

my ($teiCorpus_fileIn) = glob "$data_dir/$input_dir/$run_id/ParlaMint-UA.xml";
unless($teiCorpus_fileIn){
  print STDERR "no input corpus file $data_dir/$input_dir/$run_id/ParlaMint-UA.xml\n";
  exit 1;
}
my $teiCorpus = open_xml($teiCorpus_fileIn);

die "invalid corpus file" unless $teiCorpus;

my @file_list = map {$_->getAttribute('href')} $teiCorpus->findnodes('/*[local-name() = "teiCorpus"]/*[local-name() = "include" and @href]');
my $stat = {};
my %usage_len;

exit 1 unless @file_list;

`mkdir -p $data_dir/$output_dir/$run_id`;

for my $l (@langs){
  $l = decode('UTF-8', $l, Encode::FB_CROAK);
  my ($lang,$translations) = $l =~ m/^(\w+):((?:\w+=\p{Ll}+)(?:,\w+=\p{Ll}+)*)$/;
  if($lang){
    $lang_translations->{$lang} //= {};
    for my $tr (split(',',$translations)){
      my ($c,$t) = $tr =~ m/^(\w+)=(\p{Ll}+)$/;
      $lang_translations->{$lang}->{$c} = $t;
      print STDERR "INFO: translation of $lang into $c is $t\n";
    }
  }  else {
    print STDERR "ERROR: invalid option format --lang '$l'. Expected value: '{lang_code}:{translation_lang_code}={translation_lang_name},{translation_lang_code2}={translation_lang_name2}'\n"
  }
}

for my $file (@file_list){
  my $tei = open_xml("$data_dir/$input_dir/$run_id/$file");
  for my $node ($tei->findnodes('.//*[local-name() = "seg"]')){
    my $role = $node->parentNode->getAttribute('ana');
    my $text = $node->textContent();
    my $lng = detect_language($node,$text);
    my @check_context = ();
    unless (defined $lng->{char} or defined $lng->{word}) {
      push @check_context, status_lang($lng,$text,"too short, checking for context '$text'") if length($text) < 20;
      push @check_context, status_lang($lng,$text,"not confident") if $lng->{identify}->{conf}*1 < 0.8;
      push @check_context, status_lang($lng,$text,"different from uk") if $lng->{identify}->{lang} ne 'uk';
      if(@check_context){
        print STDERR "INFO: ",$node->getAttributeNS('http://www.w3.org/XML/1998/namespace','id')," ",$check_context[0],"\n";
        $text = $node->parentNode->textContent();
        $lng = detect_language($node,$text);
        print STDERR "INFO: ",$node->getAttributeNS('http://www.w3.org/XML/1998/namespace','id')," ",status_lang($lng,$text, 'FIXED'),"\n";
      }
    }
print STDERR $node->getAttributeNS('http://www.w3.org/XML/1998/namespace','id'),"\t",$lng->{char} ,'?', $lng->{identify}->{lang},"\t$text\n" if $lng->{char} && $lng->{char} ne $lng->{identify}->{lang};
    my $lang = $lng->{char} // $lng->{word} // $lng->{identify}->{lang};
    unless($lang eq 'uk' or $lang eq 'ru'){
      print STDERR "WARN language[$lang]:$text\n";
      if(length($node->textContent())<100){
        print STDERR "WARN too short, setting uk\n";
        $lang = 'uk';
      }
    }
    $usage_len{$lang} //= 0;
    $usage_len{$lang} += length($node->textContent());
    $node->setAttributeNS('http://www.w3.org/XML/1998/namespace','lang',$lang);
    my $u = $node->parentNode;
    $stat->{$u->getAttribute('who')} //= {};
    $stat->{$u->getAttribute('who')}->{$u->getAttribute('ana')} //= {};
    $stat->{$u->getAttribute('who')}->{$u->getAttribute('ana')}->{$lang} //= 0;
    $stat->{$u->getAttribute('who')}->{$u->getAttribute('ana')}->{$lang} += 1;
  }
  # check if not "uk" speech was made by someone who speaks "uk"
  # TODO
  save_xml($tei,"$data_dir/$output_dir/$run_id/$file");
}

print STDERR "INFO: ",(scalar @file_list)," files processed\n";

my $total_len = 0;
for my $l (keys %usage_len){
  $total_len += $usage_len{$l};
  print STDERR "INFO: language $l contains $usage_len{$l} characters\n";
}
if(@langs){
  my $node = $teiCorpus->documentElement();
  for my $node_name (qw/teiHeader profileDesc langUsage/){
    my ($n) = grep {$_->nodeName eq $node_name} $node->childNodes;
    if($n){
      $node = $n;
    } else {
      $node = $node->addNewChild('http://www.tei-c.org/ns/1.0',$node_name);
    }
  }
  for my $l (sort {$usage_len{$b} <=> $usage_len{$a}} keys %usage_len){
    my $perc = sprintf("%.0f",100*$usage_len{$l}/$total_len);
    print STDERR "INFO: language $l contains $perc \%\n";
    for my $c (sort keys %{$lang_translations->{$l}}){
      my $lnode = $node->addNewChild('http://www.tei-c.org/ns/1.0','language');
      $lnode->setAttributeNS('http://www.w3.org/XML/1998/namespace','lang',$c);
      $lnode->setAttribute('ident',$l);
      $lnode->setAttribute('usage',$perc);
      $lnode->appendTextNode($lang_translations->{$l}->{$c});
    }
  }
}

  save_xml($teiCorpus,"$data_dir/$output_dir/$run_id/".basename($teiCorpus_fileIn));


if($lang_stats){
  my $file = "$data_dir/$output_dir/$run_id/speaker_lang_stat.tsv";
  print STDERR "INFO: printing speaker language statistic $file\n";
  open FILE, ">$file";
  print FILE "who\trole\tlang\tcnt\n";
  for my $who (sort keys %$stat){
    for my $ana (sort keys %{$stat->{$who}}){
      for my $lang (sort keys %{$stat->{$who}->{$ana}}){
        print FILE "$who\t$ana\t$lang\t",$stat->{$who}->{$ana}->{$lang},"\n";
      }
    }
  }
  close FILE;
}
sub status_lang  {
  my($lng,$text,$msg) = @_;
  return sprintf("INFO: lang=%s\tconf=%s\tlen=%d\t%s",$lng->{identify}->{lang},$lng->{identify}->{conf},length($text),$msg//'');
}

sub detect_language {
  my ($node,$text) = @_;
  my %res;
  my $lng = detect_text_language(text => $text);
  my $uk = () = $text =~ m/([іїєґ])/gi;
  my $ru = () = $text =~ m/([ыэъ])/gi;
  my $dig = () = $text =~ m/([0-9])/g;
  $res{char} = $uk >= $ru ? 'uk' : 'ru' if $uk || $ru;
  $res{char} = 'uk' if 3 * $dig >= length($text); #set uk if text contains >= 1/3 digits

  my $ukw = () = $text =~ m/\b($uk_words)\b/gi;
  my $ruw = 0;
  $res{word} = $ukw >= $ruw ? 'uk' : 'ru' if $ukw || $ruw;

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