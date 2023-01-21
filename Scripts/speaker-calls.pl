#!/usr/bin/env perl

use warnings;
use strict;
use open qw(:std :utf8);
use utf8;
use Getopt::Long;
use XML::LibXML;


use File::Basename;
use File::Path;

use Data::Dumper;

use Text::Levenshtein qw(distance);

my ($data_dir, $run_id, $config_path);

my $max_edit_dist = 3;

GetOptions (
            'data-dir=s' => \$data_dir,
            'id=s' => \$run_id,
            'config=s' => \$config_path
        );
my %config = map {m/^([^=]*)="(.*)"$/; $1 => $2} grep{m/^([^=]*)="(.*)"$/} split("\n",`./$config_path list`);

my $input_dir = $config{tei_UD};
my $output_dir = $config{speaker_calls};

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

my @file_list = sort map {"$data_dir/$input_dir/$run_id/".$_->getAttribute('href')} $teiCorpus->findnodes('/*[local-name() = "teiCorpus"]/*[local-name() = "include" and @href]');


exit 1 unless @file_list;

`mkdir -p $data_dir/$output_dir/$run_id`;

open CALLS_SENT, ">$data_dir/$output_dir/$run_id/calls-sentences.tsv";
open CALLS_SPEAKER, ">$data_dir/$output_dir/$run_id/calls-speakers.tsv";

print CALLS_SENT "utterance\tnote\twho\tsentence\n";
print CALLS_SPEAKER "utterance\tnote\twho\twordIds\tforename\tpatronymic\tsurname\tsex\tdist\tisFull\n";

for my $fileIn (@file_list){
  my $tei = open_xml($fileIn);
  for my $node ($tei->findnodes('.//*[local-name() = "u"]')){
    my @full_names;
    my $who = $node->getAttribute('who');
    my $ana = $node->getAttribute('ana');
    my $id = $node->getAttributeNS('http://www.w3.org/XML/1998/namespace','id');
    my ($speaker_note) = $node->findnodes('./preceding-sibling::*[local-name() = "note"][1][@type="speaker"]');
    my ($prev_u) = $node->findnodes('./preceding-sibling::*[local-name() = "u"][1]');
    next unless $prev_u;
    my @speaker_pattern = get_speaker_pattern($who,$speaker_note->textContent,$ana);
    next unless @speaker_pattern;
    print STDERR "INFO: find speaker in text\t$id\t$who\t$speaker_note\n";
    print STDERR 'INFO: patterns ',join(" ",map {$_->{attr}->{lemma}->{txt}} @speaker_pattern),"\n";
    my $data = {
          who => $who,
          note => $speaker_note->textContent,
          ana => $ana,
          speech => $id,
        };
    my ($sur) = grep {defined $_->{sur}} @speaker_pattern;

    for my $sur_node ( grep {
                              substr($_->getAttribute('lemma'),0,1) eq substr($sur->{attr}->{lemma}->{txt},0,1)
                              && distance($_->getAttribute('lemma'), $sur->{attr}->{lemma}->{txt}) <= $max_edit_dist
                            } $prev_u->findnodes('.//*[local-name() = "w"]')){
      my $sur_id = $sur_node->getAttributeNS('http://www.w3.org/XML/1998/namespace','id');
      # traverse tree (closest)
      my $sur_dist = distance($sur_node->getAttribute('lemma'), $sur->{attr}->{lemma}->{txt});
      get_full_name($data,{$sur_id => {%$sur,node => $sur_node }},$sur_node, $sur_dist, grep {not defined $_->{sur}} @speaker_pattern);
    }
  }
}

print STDERR "INFO: ",(scalar @file_list)," files processed\n";
close CALLS_SENT;
close CALLS_SPEAKER;

sub get_speaker_pattern {
  my ($who,$note,$role) = @_;
  my $name = ($who =~ m/#/) ? $note : $who;
  return () if $name =~ m/ГОЛОВУЮ?Ч(?:ИЙ|А)/;
  $name =~ s/\./\. /g;
  $name=~ s/ *$//;
  my @text = grep {$_} split(' ', $name);

  print STDERR '==',join("\t",@text),"\n";
  if ($name =~ m/\./){
    push @text, (shift @text);
  }
  print STDERR '##',join("\t",@text),"\n";
  my @pat;
  for my $i (0..$#text){
    my $t = $text[$i];

    my $p = $t;
    if($p =~ m/\.$/){
      $p .= '*';
    } else {
      $p =~ s/^(\w)(.*)$/$1\L$2/
    }
    my $m;
    if($i == $#text){$m = 'Sur'}
    elsif($i == 0){$m = 'Giv'}
    else {$m = 'Sur|Giv|Pat'}
    push @pat, {
                 ord => $i,
                 attr => {
                   lemma => {
                    re => qr/^$p$/,
                    txt => $p
                    },
                   msd => qr/\bNodeType=(:?$m)\b/
                 },
                 $i == $#text ? (sur=>1) : (),
               }
  }
  return @pat;
}

sub get_full_name {
  my ($data,$seen,$node, $dist,@patterns) = @_;

  my $extended = 0;
  for my $i (0..$#patterns){
    # check parent and childs of $node
    my $pat = $patterns[$i];
    my @linked_nodes =  grep {
                          $_->getAttribute('lemma') =~ $pat->{attr}->{lemma}->{re}
                          && not defined $seen->{$_->getAttributeNS('http://www.w3.org/XML/1998/namespace','id')}
                        } get_linked_nodes($node);
    for my $nd (@linked_nodes){
      # next node is linked to parent/child
      get_full_name($data,{%$seen,$nd->getAttributeNS('http://www.w3.org/XML/1998/namespace','id') => {%$pat,node=>$nd}},$nd, $dist, grep {$_->{ord} != $pat->{ord}} @patterns );
      $extended = 1;
    }
    last if $extended;
  }
  unless($extended){
    # try to match with following/preceding nodes
    if(scalar(@patterns)){
      my @name_nodes = map {$_->{node}} values %$seen;
      while(my $cur_node = shift @name_nodes){
        my @explore_dir = qw/following preceding/;
        while(my $dir = shift @explore_dir){
          my ($nd) = $cur_node->findnodes("./$dir-sibling::*[1]");
          next unless $nd;
          my $nd_id = $nd->getAttributeNS('http://www.w3.org/XML/1998/namespace','id');
          next if defined $seen->{$nd_id};
          next unless $nd->hasAttribute('lemma');
          for my $pat (@patterns){
            if($nd->getAttribute('lemma') =~ $pat->{attr}->{lemma}->{re}){
              @patterns = grep {$_->{ord} != $pat->{ord}} @patterns;
              $seen->{$nd_id} = {%$pat,node=>$nd};
              push @name_nodes, $nd;
              last;
            }
          }
        }
      }

    }
    print_sentence($data, $node->findnodes('./ancestor::*[local-name() = "s"][1]'), keys %$seen);
    print_speaker($data,$seen, $dist, ! scalar(@patterns))
  }
}


sub get_linked_nodes {
  my $node = shift;
  my $node_id = $node->getAttributeNS('http://www.w3.org/XML/1998/namespace','id');
  my @link_ids = map { s/\s*#${node_id}\s*//; s/#//; $_}
                 grep {m/#${node_id}\b/}
                 map {$_->getAttribute('target')}
                     $node->findnodes('./ancestor::*[local-name()="s"][1]/*[local-name()="linkGrp" and @type="UD-SYN"]/*[local-name()="link"]');
  return map {$node->findnodes('./ancestor::*[local-name()="s"]//*[local-name()="w" and @xml:id="'.$_.'"]')} @link_ids;
}


sub print_sentence {
  my $data = shift;
  my $s = shift;
  my %highlight_isd = map {$_ => 1} @_;
  print CALLS_SENT $data->{speech},
                   "\t",
                   $data->{note},
                   "\t",
                   $data->{who},
                   "\t";
  for my $ch (grep {$_->localName eq 'w' || $_->localName eq 'pc'} grep {ref $_ eq 'XML::LibXML::Element'} $s->childNodes()){
    my $highlight = defined $highlight_isd{$ch->getAttributeNS('http://www.w3.org/XML/1998/namespace','id')};
    print CALLS_SENT '[' if $highlight;
    print CALLS_SENT $ch->textContent;
    print CALLS_SENT ']('.$ch->getAttributeNS('http://www.w3.org/XML/1998/namespace','id').')' if $highlight;
    print CALLS_SENT ' ' unless $ch->hasAttribute('join');
  }
  print CALLS_SENT "\n";
}

sub print_speaker {
  my $data = shift;
  my $seen = shift;
  my $dist = shift;
  my $is_full = shift;
  print CALLS_SPEAKER
               $data->{speech},
               "\t",
               $data->{note},
               "\t",
               $data->{who},
               "\t",
               join(' ', map {$_->{node}->getAttributeNS('http://www.w3.org/XML/1998/namespace','id')} sort {$a->{ord}<=>$b->{ord}} values %$seen);
  my $i = -1;
  for my $s (sort {$a->{ord}<=>$b->{ord}} values %$seen){
    while($i < $s->{ord}){
      print CALLS_SPEAKER "\t";
      $i++
    }
    print CALLS_SPEAKER $s->{node}->getAttribute('lemma')
  }
  print CALLS_SPEAKER "\t",map {$_->{node}->getAttribute('msd') =~ m/Gender=\b(.)/;$1} grep {$_->{ord} == 2} values %$seen;
  print CALLS_SPEAKER
               "\t",
               $dist,
               "\t",
               ($is_full || 0)
               ;
  print CALLS_SPEAKER "\n";
}
##-----------------------------

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