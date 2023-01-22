# ParlaMint-UA
Tools and samples of Ukrainian parliamentary proceedings encoded in ParlaMint format


```mermaid
graph TB
    VR(Verkhovna Rada):::in
    
    DM[fa:fa-users download-meta<br><small>metadata about MPs</small>]
    VR --> DM
    DMsp[download-meta-speeches<br><small>metadata about plenary speeches</small>]
    VR --> DMsp
    tei-particDesc[tei-particDesc]
    DM --> tei-particDesc
    DMsp --> tei-particDesc

    tei-particDesc -. calls .-> tei-particDesc-preprocess(tei-particDesc-preprocess):::gr
    tei-particDesc-preprocess -.-> tei-particDesc
    tei-particDesc-preprocess -. calls .-> tei-particDesc-gov(tei-particDesc-gov):::gr
    tei-particDesc-gov -.-> tei-particDesc-preprocess
    GOV([manual adding persons<br>government, president]):::MANUAL
    GS(Google sheet):::in 
    GOV ----> GS
    GS --> tei-particDesc-gov
    tei-particDesc --listPerson--> tei-particDesc-aliases(tei-particDesc-aliases)
 
    DP[fa:fa-file-text download<br><small>plenary speeches in HTML</small>]
    VR --> DP

    HTML[html2tei-text<br><small>convert HTML to TEI<br>text content <br>+ small mount of teiHeader info</small>]
    DP --> HTML
    TEIlang[tei-text-lang<br><small>add xml:lang + langUsage </small>]
    HTML --> TEIlang
    TEIud[tei-UD<br><small>annotate with UDPipe uk+ru</small>]
    TEIlang --> TEIud
    SC[speaker-calls<br><small>find speaker mentions</small>]
    TEIud --> SC
    
    TEIner[NER]:::TODO
    TEIud --> TEIner

    link-speakers[link-speakers]
    HTML --> link-speakers
    SC --calls-speakers.tsv--> link-speakers
    tei-particDesc-aliases --> link-speakers
    tei-particDesc --plenary-speech.xml--> link-speakers

    mismatching-speakers[mismatching-speakers]
    link-speakers --speaker-person-links.tsv--> mismatching-speakers
    manMiss([manually adding<br>mismatching guest]):::MANUAL
    mismatching-speakers --tsv--> manMiss
    manMiss --guest sheet-->GS
    
    link-speaker-final[link-speaker-final]:::TODO
    GS --guest--> link-speaker-final
    link-speakers --speaker-person-links.tsv--> link-speaker-final

    TEIana[TEI.ana<br>partially implemented<br>changing names and ids !!!<br>FINALIZATION]:::TODOfin
    link-speaker-final --> TEIana
    TEIner --> TEIana
    
    TEI[TEI<br>FINALIZATION]:::TODOfin
    TEIana --speakers+numbers-->TEI
    TEIlang -->TEI
    
    classDef default fill:#ddf,stroke:#333,stroke-width:2px;
    classDef in fill:#ff3;
    classDef gr fill:#eee,stroke:#aaa,stroke-width:1px;
    classDef TODO fill:#fff,stroke:#aaa;
    classDef TODOfin fill:#fff,stroke:#00f,stroke-width:4px;
    classDef MANUAL fill:#df3,stroke-width:0px;
```
