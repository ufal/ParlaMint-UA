# Named entities annotation of ParlaMint-UA

This branch serves for manual named entity annotation of a subset of ParlaMint-UA corpus. The subset contains documents with `>=600` and `<=8000` words; only Ukrainian paragraphs are included.

## Data

Automatic named entity recognition done with [NameTag 2](https://ufal.mff.cuni.cz/nametag/2) and [languk-230306](https://ufal.mff.cuni.cz/nametag/2/models#ukrainian-languk) was done before manual annotation. And the tokenization was done with [UDPipe 2](https://ufal.mff.cuni.cz/udpipe/2).

### File structure

- `Makefile` - script for initialization repository and creation train/test set division
- `Release/ParlaMint-UA.TEI.ana` (not part of this repository) - ParlaMint-UA annotated version v3.0

Automatically generated with `make prepare-annotation-task`:
- `Data/Source` - source data in ParlaMint TEI and brat format
- `Data/Annotation` - manually annotated named entities in brat format

## Named Entities

- **PER**
- **ORG**
- **LOC**
- **MISC**
