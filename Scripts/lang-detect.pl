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
будемо буде
будь ласка
ви
вибачатися вибачаюся вибачаюсь вибачте
визначатися визначитися визначайтеся
враховувати врахувати враховано врахована враховані врахуйте
голово
голосування
добре
дякую
завершити завершуйте завершив завершила завершую
запрошувати запрошую запрошуйте запрошував запросити запросив запросила запросили запрошу
зараз
йти йдемо
Князевич
ми
Микола
надати
народний
наступний наступна наступне наступного
нема немає
пане
передати
перепрошувати перепрошую
поважати поважаю
повернення
повернутись повернутися повернуться повертаємось повернемся
приймати прийнято
продовжити продовжуйте продовжуй
просимо
підтвердити підтвердитися
спасибі
тепер
треба
хвилина хвилину хвилин хвилини хвилинку хвилиночку
хотіти хочете
хто
хтось
цей ця це цього
шановний шановна
ще
що
як
який яка яке якого якому яку
/;
my $uk_words = join('|',@uk_words);
my $uk_words_max_text_length = 250;


my @ru_words = qw/
администрация администрации
Александр Александру
Балицкий
благодарен благодарна
благодарить благодарю благодарите
большой большое большая большие большим больше
Владимир Владимиру
вместе
внимание внимания вниманием
вопрос вопроса
вот
всех всем
второй вторая второе
главное главная главного главному
говорите
господин госпожа
действовать действую
деятельность деятельности
диалог диалоге диалога
договариваться
Евгений Евгению
его
ее
если
есть
еще
ещё
её
закончить закончу заканчивайте
замечание замечания замечаний замечаниями
занять
здравствуйте здравствуй
и
Иван Ивану
из
или
Инна Инне
Ирина Ирине
их им
как
когда
коллега коллеги коллеге коллегам
коллеге
коллектив коллективу коллектива
конечно
Мариуполь
Матвиенков Матвиенкову
Мелитополь
меня мне
минута минутой
Михаил Михаилу
надеяться надеюсь надеемся надейтесь
народный народных
настаивать
Наталья Наталье
начать
Николай Николаю
нужен нужна нужно
партия партии
передать
подать подавать
подготовиться подготовились подготовтесь
поддержать поддержите поддерживаем поддерживать
подтвердить
пожалуйста
политический политическая
понимание понимания пониманием
последний последнее последнего
предлагать предлагаю
председатель
Председательствующий
применять применяю
продолжать продолжает
прощение прощения
работа работу
работать
Раиса Раисе
регионов регионам
Сергей Сергею
сессия сессии
сказать сказал
согласно
спасибо
сразу
также
Татьяна Татьяне
тебя
только
тратить
уважение уважением
уверен уверена
Украина Украине
фракция фракции фракций фракциях
хорошо
чтение чтении
что
Юрий Юрию
/;
my $ru_words = join('|',@ru_words);
my $ru_words_max_text_length = 100;

my $short_text_length = 50;

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
      print STDERR $node->getAttributeNS('http://www.w3.org/XML/1998/namespace','id'),"\t",$lng->{char}//'-','?', $lng->{word}//'-','?', $lng->{length}//'-','?', $lng->{identify}->{lang},"\n";
      push @check_context, status_lang($lng,$text,"too short, checking for context '$text'") if length($text) < 100;
      push @check_context, status_lang($lng,$text,"not confident") if $lng->{identify}->{conf}*1 < 0.8;
      push @check_context, status_lang($lng,$text,"different from uk") if $lng->{identify}->{lang} ne 'uk';
      if(@check_context){
        print STDERR "INFO: ",$node->getAttributeNS('http://www.w3.org/XML/1998/namespace','id')," ",$check_context[0],"\n";
        $text = $node->parentNode->textContent();
        $lng = detect_language($node,$text);
        print STDERR "INFO: ",$node->getAttributeNS('http://www.w3.org/XML/1998/namespace','id')," ",status_lang($lng,$text, 'FIXED'),"\t'$text'\n";
      }
    }
    print STDERR $node->getAttributeNS('http://www.w3.org/XML/1998/namespace','id'),"\t",$lng->{char}//'-','?', $lng->{word}//'-','?', $lng->{length}//'-','?', $lng->{identify}->{lang},"\n";
    my $lang = $lng->{char} // $lng->{word} // $lng->{length} // $lng->{identify}->{lang};
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
    unless($lang eq 'uk'){
      # set xml lang uk for notes
      for my $nd ($node->findnodes('.//*[local-name() = "note" or local-name() = "desc"]')){
        $nd->setAttributeNS('http://www.w3.org/XML/1998/namespace','lang', 'uk');
      }
    }
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
  $text =~ s/\s+/ /g;
  $text =~ s/^\s+|\s+$//g;
  my %res;
  my $lng = detect_text_language(text => $text);
  my $len = length(only_letters($text)) || 1; ### avoid division by zero
  # expected freqencies: 6.23 %(і) + 0.84 %(ї) + 0.39 %(є) + 0.01 %(ґ) = 7.47 %
  my $uk = () = $text =~ m/([іїєґ])/gi;
  my $exp_uk_freq = 0.0747;
  my $uk_freq = $uk / $len;
  # expected freqencies: 2.36 %(ы) + 0.36 %(э) + 0.2 % (ё)+ 0.02 %(ъ) = 2.94%
  my $ru = () = $text =~ m/([ыэъё])/gi;
  my $exp_ru_freq = 0.0294;
  my $ru_freq = $ru / $len;
  my $dig = () = $text =~ m/([0-9])/g;
  $res{char} = $uk_freq >= $ru_freq ? 'uk' : 'ru' if ($uk_freq >= 0.5*$exp_uk_freq) || ($ru_freq >= 0.5*$exp_ru_freq);
  $res{char} = 'uk' if 3 * $dig >= length($text); #set uk if text contains >= 1/3 digits

  my $ukw = () = $text =~ m/\b($uk_words)\b/gi;
  my $ruw = () = $text =~ m/\b($ru_words)\b/gi;
  if(length($text) <= $uk_words_max_text_length && $ukw){
    $res{word} = 'uk';
  } elsif (length($text) <= $ru_words_max_text_length && $ruw){
    $res{word} = 'ru';
  }

  $res{length} = 'uk' if length($text) <= $short_text_length;
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

sub only_letters{
  my $t = shift;
  $t =~ s/[^-\p{Lu}\p{Lt}\p{Ll}\d'’`]//g;
  return $t;
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