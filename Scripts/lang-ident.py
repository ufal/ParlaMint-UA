import glob, os
import sys, getopt
from lingua import Language, LanguageDetectorBuilder
import pandas as pd
import csv

def ensure_directory_exists(directory_path):
  if not os.path.exists(directory_path):
    os.makedirs(directory_path)
  return directory_path

def main(argv):
  def lang_ident(text):
    return detector.detect_language_of(text).name
  languages = [Language.UKRAINIAN, Language.RUSSIAN]
  detector = LanguageDetectorBuilder.from_languages(*languages).build()
  indir = ''
  outdir = ''
  opts, args = getopt.getopt(argv,"hi:o:",["indir=","outdir="])
  for opt, arg in opts:
    if opt == '-h':
      print ('test.py -i <inputdirectory> -o <outputdirectory>')
      sys.exit()
    elif opt in ("-i", "--indir"):
      indir = arg
    elif opt in ("-o", "--outdir"):
      outdir = os.path.abspath(arg)
  print ('Input dir is ', indir)
  print ('Output dir is ', outdir)
  ensure_directory_exists(indir)
  os.chdir(indir)
  for file in glob.glob("**/*.tsv"):
    print("INFO: opening "+ file)
    df = pd.read_csv(file, sep='\t')
    df['language'] = df['text'].apply(lang_ident)
    ensure_directory_exists(os.path.dirname(outdir + "/" + file))
    df.to_csv(outdir + "/" + file, sep='\t', index=False, escapechar='', quotechar='',quoting=csv.QUOTE_NONE)
    print("INFO: saving "+ file)



if __name__ == "__main__":
   main(sys.argv[1:])






