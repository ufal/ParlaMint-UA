<?xml version="1.0"?>
<!-- Takes root file as input, and outputs it and all finalized component files to outDir:
     -
-->
<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xi="http://www.w3.org/2001/XInclude"
  xmlns="http://www.tei-c.org/ns/1.0"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  exclude-result-prefixes="xsl tei xs xi"
  version="2.0">

  <xsl:import href="ParlaMint-UA-lib.xsl"/>

  <!-- Directories must have absolute paths! -->
  <xsl:param name="inListPerson"/>
  <xsl:param name="inListOrg"/>
  <xsl:param name="inTaxonomiesDir"/>
  <xsl:param name="outDir"/>
  <xsl:param name="anaDir"/>
  <xsl:param name="type"/> <!-- TEI or TEI.ana-->
  <xsl:param name="speakers"/>


  <xsl:param name="version">3.0a</xsl:param>
  <xsl:param name="covid-date" as="xs:date">2019-11-01</xsl:param>
  <xsl:param name="handle-txt">http://hdl.handle.net/11356/XXXX</xsl:param>
  <xsl:param name="handle-ana">http://hdl.handle.net/11356/XXXX</xsl:param>

  <xsl:output method="xml" indent="yes"/>
  <xsl:preserve-space elements="catDesc seg p"/>

  <!-- Input directory -->
  <xsl:variable name="inDir" select="replace(base-uri(), '(.*)/.*', '$1')"/>
  <!-- The name of the corpus directory to output to, i.e. "ParlaMint-XX" -->
  <xsl:variable name="corpusDir" select="concat('ParlaMint-UA.',$type)"/>

  <xsl:variable name="languages">
    <item xml:lang="uk">
      <language xml:lang="en">ukrainian</language>
      <language xml:lang="uk">українська</language>
    </item>
    <item xml:lang="ru">
      <language xml:lang="en">russian</language>
      <language xml:lang="uk">російська</language>
    </item>
  </xsl:variable>

  <xsl:variable name="taxonomies">
    <item>ParlaMint-taxonomy-parla.legislature.xml</item>
    <item>ParlaMint-taxonomy-speaker_types.xml</item>
    <item>ParlaMint-taxonomy-subcorpus.xml</item>
    <item>ParlaMint-UA-taxonomy-affiliation.roles.xml</item>
    <xsl:if test="$type = 'TEI.ana'">
      <item>ParlaMint-taxonomy-UD-SYN.ana.xml</item>
      <item>ParlaMint-taxonomy-NER.ana.xml</item>
    </xsl:if>
  </xsl:variable>

  <xsl:variable name="speaker-person">
    <xsl:variable name="table">
      <xsl:call-template name="read-tsv">
        <xsl:with-param name="file" select="$speakers"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:for-each select="$table//row">
      <xsl:if test="./col[@name='who']">
        <item utterance="{./col[@name='utterance']}" doc="{./col[@name='utterance']}" who="{./col[@name='who']}" ana="{./col[@name='ana']}"/>
      </xsl:if>
    </xsl:for-each>
  </xsl:variable>

  <xsl:variable name="today" select="format-date(current-date(), '[Y0001]-[M01]-[D01]')"/>
  <xsl:variable name="outRoot">
    <xsl:value-of select="$outDir"/>
    <xsl:text>/</xsl:text>
    <xsl:value-of select="$corpusDir"/>
    <xsl:text>/</xsl:text>
    <xsl:value-of select="replace(base-uri(), '.*/(.+).xml$', '$1')"/>
    <xsl:choose>
      <xsl:when test="$type = 'TEI.ana'">.ana.xml</xsl:when>
      <xsl:when test="$type = 'TEI'">.xml</xsl:when>
      <xsl:otherwise>
        <xsl:message terminate="yes">invalid type param: allowed values are 'TEI' and 'TEI.ana'</xsl:message>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:variable name="url-corpus-ana" select="concat($anaDir, '/', replace(base-uri(), '.*/(.+)\.xml', '$1.ana.xml'))"/>


  <xsl:variable name="suff">
    <xsl:choose>
      <xsl:when test="$type = 'TEI.ana'">.ana</xsl:when>
      <xsl:otherwise><text/></xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <!-- Gather URIs of component xi + files and map to new files, incl. .ana files -->
  <xsl:variable name="docs">
    <xsl:for-each select="/tei:teiCorpus/xi:include">
      <item>
        <xi-orig>
          <xsl:value-of select="@href"/>
        </xi-orig>
        <url-orig>
          <xsl:value-of select="concat($inDir, '/', @href)"/>
        </url-orig>
        <url-new>
          <xsl:value-of select="concat($outDir, '/', $corpusDir, '/')"/>
          <xsl:choose>
            <xsl:when test="$type = 'TEI.ana'"><xsl:value-of select="replace(@href,'\.xml$','.ana.xml')"/></xsl:when>
            <xsl:when test="$type = 'TEI'"><xsl:value-of select="@href"/></xsl:when>
          </xsl:choose>
        </url-new>
        <xi-new>
          <xsl:choose>
            <xsl:when test="$type = 'TEI.ana'"><xsl:value-of select="replace(@href,'\.xml$','.ana.xml')"/></xsl:when>
            <xsl:when test="$type = 'TEI'"><xsl:value-of select="@href"/></xsl:when>
          </xsl:choose>
        </xi-new>
        <url-ana>
          <xsl:value-of select="concat($anaDir, '/', replace(@href, '\.xml', '.ana.xml'))"/>
        </url-ana>
      </item>
      </xsl:for-each>
  </xsl:variable>

  <!-- Numbers of words in component .ana files -->
  <xsl:variable name="words">
    <xsl:for-each select="$docs/tei:item">
      <item n="{tei:xi-orig}">
        <xsl:choose>
          <!-- For .ana files, compute number of words -->
          <xsl:when test="$type = 'TEI.ana'">
            <xsl:value-of select="document(tei:url-orig)/
                                  count(//tei:w[not(parent::tei:w)])"/>
          </xsl:when>
          <!-- For plain files, take number of words from .ana files -->
          <xsl:when test="doc-available(tei:url-ana)">
            <xsl:value-of select="document(tei:url-ana)/tei:TEI/tei:teiHeader//
                                  tei:extent/tei:measure[@unit='words'][1]/@quantity"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:message select="concat('ERROR ', /tei:TEI/@xml:id,
                                   ': cannot locate .ana file ', tei:url-ana)"/>
            <xsl:value-of select="number('0')"/>
          </xsl:otherwise>
        </xsl:choose>
      </item>
    </xsl:for-each>
  </xsl:variable>

  <!-- Numbers of tokens in component .ana files -->
  <xsl:variable name="tokens">
    <xsl:for-each select="$docs/tei:item">
      <xsl:variable name="doc-url" select="./tei:url-orig"/>
      <item n="{tei:xi-orig}">
        <xsl:for-each select="$languages/tei:item">
          <xsl:variable name="lang" select="."/>
          <lang n="{$lang/@xml:lang}">
            <xsl:choose>
              <!-- For .ana files, compute number of tokens -->
              <xsl:when test="$type = 'TEI.ana'">
                <xsl:value-of select="document($doc-url)/
                                    count(
                                           //tei:w[ancestor-or-self::tei:*[@xml:lang][1]/@xml:lang = $lang/@xml:lang][not(parent::tei:w)]
                                           | //tei:pc[ancestor-or-self::tei:*[@xml:lang][1]/@xml:lang = $lang/@xml:lang]
                                         )"/>
              </xsl:when>
            </xsl:choose>
          </lang>
        </xsl:for-each>
      </item>
    </xsl:for-each>
  </xsl:variable>

  <xsl:variable name="langUsage">
    <xsl:for-each select="$languages/*/@xml:lang">
      <xsl:variable name="lang" select="."/>
      <lang n="{$lang}">
        <xsl:choose>
          <xsl:when test="$type = 'TEI.ana'">
            <xsl:value-of select="round(100 * sum($tokens/tei:item/tei:lang[@n=$lang]) div sum($tokens/tei:item/*),0)"/> <!--  / sum($tokens/tei:item/*) -->
          </xsl:when>
        </xsl:choose>
      </lang>
    </xsl:for-each>
  </xsl:variable>

  <!-- Terms in component files -->
  <xsl:variable name="terms">
    <xsl:for-each select="$docs/tei:item">
      <item n="{tei:xi-orig}">
        <xsl:copy-of select="document(tei:url-orig)/tei:TEI/tei:teiHeader//tei:meeting[contains(@ana,'#parla.term')]"/>
      </item>
    </xsl:for-each>
  </xsl:variable>

  <!-- Dates in component files -->
  <xsl:variable name="dates">
    <xsl:for-each select="$docs/tei:item">
      <item n="{tei:xi-orig}">
        <xsl:value-of select="document(tei:url-orig)/tei:TEI/tei:teiHeader//tei:settingDesc/tei:setting/tei:date/@when"/>
      </item>
    </xsl:for-each>
  </xsl:variable>
  <xsl:variable name="corpusFrom" select="replace(min($dates/tei:item/translate(.,'-','')),'(....)(..)(..)','$1-$2-$3')"/>
  <xsl:variable name="corpusTo" select="replace(max($dates/tei:item/translate(.,'-','')),'(....)(..)(..)','$1-$2-$3')"/>


  <!-- Numbers of speeches in component files -->
  <xsl:variable name="speeches">
    <xsl:for-each select="$docs/tei:item">
      <item n="{tei:xi-orig}">
        <xsl:value-of select="count(document(tei:url-orig)/tei:TEI/tei:text//tei:u)"/>
      </item>
    </xsl:for-each>
  </xsl:variable>

  <!-- calculate tagUsages in component files -->
  <xsl:variable name="tagUsages">
    <xsl:for-each select="$docs/tei:item">
      <item n="{tei:xi-orig}">
        <xsl:variable name="context-node" select="."/>
        <xsl:for-each select="document(tei:url-orig)/
                            distinct-values(tei:TEI/tei:text/descendant-or-self::tei:*/name())">
          <xsl:sort select="."/>
          <xsl:variable name="elem-name" select="."/>
          <!--item n="{$elem-name}">
              <xsl:value-of select="$context-node/document(tei:url-orig)/
                                    count(tei:TEI/tei:text/descendant-or-self::tei:*[name()=$elem-name])"/>
          </item-->
          <xsl:element name="tagUsage">
            <xsl:attribute name="gi" select="$elem-name"/>
            <xsl:attribute name="occurs" select="$context-node/document(tei:url-orig)/
                                    count(tei:TEI/tei:text/descendant-or-self::tei:*[name()=$elem-name])"/>
          </xsl:element>
        </xsl:for-each>
      </item>
    </xsl:for-each>
  </xsl:variable>

  <xsl:template match="/">
    <xsl:message select="concat('INFO: Starting to process ', tei:teiCorpus/@xml:id)"/>
    <!-- Process component files -->
    <xsl:for-each select="$docs//tei:item">
      <xsl:variable name="this" select="tei:xi-orig"/>
      <xsl:message select="concat('INFO: Processing ', $this)"/>
      <xsl:result-document href="{tei:url-new}">
        <xsl:apply-templates mode="comp" select="document(tei:url-orig)/tei:TEI">
        <xsl:with-param name="words" select="$words/tei:item[@n = $this]"/>
        <xsl:with-param name="speeches" select="$speeches/tei:item[@n = $this]"/>
        <xsl:with-param name="tagUsages" select="$tagUsages/tei:item[@n = $this]"/>
        <xsl:with-param name="date" select="$dates/tei:item[@n = $this]/text()"/>
        </xsl:apply-templates>
      </xsl:result-document>
      <xsl:message select="concat('INFO: Saving to ', tei:xi-new)"/>
    </xsl:for-each>
    <!-- Output Root file -->
    <xsl:message>INFO: processing root </xsl:message>
    <xsl:result-document href="{$outRoot}">
      <xsl:apply-templates/>
    </xsl:result-document>
  </xsl:template>


  <xsl:template mode="comp" match="*">
    <xsl:param name="words"/>
    <xsl:param name="speeches"/>
    <xsl:param name="tagUsages"/>
    <xsl:param name="date"/>
    <xsl:copy>
      <xsl:apply-templates mode="comp" select="@*"/>
      <xsl:apply-templates mode="comp">
        <xsl:with-param name="words" select="$words"/>
        <xsl:with-param name="speeches" select="$speeches"/>
        <xsl:with-param name="tagUsages" select="$tagUsages"/>
        <xsl:with-param name="date" select="$date"/>
      </xsl:apply-templates>
    </xsl:copy>
  </xsl:template>

  <xsl:template mode="comp" match="@*">
    <xsl:copy/>
  </xsl:template>

  <xsl:template mode="comp" match="tei:TEI | tei:text">
    <xsl:param name="words"/>
    <xsl:param name="speeches"/>
    <xsl:param name="tagUsages"/>
    <xsl:param name="date"/>
    <xsl:variable name="ana">
      <xsl:choose>
        <xsl:when test="name() = 'TEI'"><xsl:text>#parla.sitting</xsl:text></xsl:when>
        <xsl:otherwise><xsl:text/></xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="covidCat">
      <xsl:choose>
        <xsl:when test="$covid-date &lt;= $date">
          <xsl:text>#covid</xsl:text>
        </xsl:when>
        <xsl:when test="$covid-date &gt; $date">
          <xsl:text>#reference</xsl:text>
        </xsl:when>
      </xsl:choose>
    </xsl:variable>
    <xsl:copy>
      <xsl:apply-templates mode="comp" select="@*[not(name() = 'ana')]"/>
      <xsl:attribute name="ana" select="normalize-space(concat($ana,' ',$covidCat))"/>
      <xsl:apply-templates mode="comp">
        <xsl:with-param name="words" select="$words"/>
        <xsl:with-param name="speeches" select="$speeches"/>
        <xsl:with-param name="tagUsages" select="$tagUsages"/>
        <xsl:with-param name="date" select="$date"/>
      </xsl:apply-templates>
    </xsl:copy>
  </xsl:template>
  <xsl:template mode="comp" match="tei:TEI/@xml:id">
    <xsl:attribute name="xml:id">
      <xsl:value-of select="concat(.,$suff)"/>
    </xsl:attribute>
  </xsl:template>

  <xsl:template mode="comp" match="tei:titleStmt">
    <xsl:param name="date"/>
    <xsl:copy>
      <title type="main" xml:lang="en">Ukrainian parliamentary corpus ParlaMint-UA, term <xsl:value-of select="./tei:meeting[contains(@ana,'#parla.term')]/@n"/>, session <xsl:value-of select="./tei:meeting[contains(@ana,'#parla.session')]/@n"/>, sitting day <xsl:value-of select="$date"/>,<xsl:value-of select="replace(ancestor::tei:TEI/@xml:id,'^.*m',' n')"/> [ParlaMint<xsl:value-of select="$suff"/>]</title>
      <title type="main" xml:lang="uk">Корпус Верховної Ради України ParlaMint-UA, <xsl:value-of select="./tei:meeting[contains(@ana,'#parla.term')]/@n"/> скликання, <xsl:value-of select="./tei:meeting[contains(@ana,'#parla.session')]/@n"/> сесія, дата пленарного засідання <xsl:value-of select="$date"/>, <xsl:value-of select="replace(ancestor::tei:TEI/@xml:id,'^.*m','номер засідання №')"/> [ParlaMint<xsl:value-of select="$suff"/>]</title>

      <xsl:apply-templates select="tei:meeting"/>
      <meeting ana="#parla.sitting #parla.uni">
        <xsl:attribute name="n" select="$date"/>
        <xsl:value-of select="$date"/>
      </meeting>
      <xsl:call-template name="add-respStmt"/>
      <xsl:call-template name="add-funder"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template mode="comp" match="tei:extent">
    <xsl:param name="words"/>
    <xsl:param name="speeches"/>
    <xsl:copy>
      <xsl:call-template name="add-measure-speeches">
        <xsl:with-param name="quantity" select="$speeches"/>
      </xsl:call-template>
      <xsl:call-template name="add-measure-words">
        <xsl:with-param name="quantity" select="$words"/>
      </xsl:call-template>
    </xsl:copy>
  </xsl:template>


  <xsl:template mode="comp" match="tei:bibl">
    <xsl:copy>
      <xsl:call-template name="add-bibl-title"/>
      <xsl:apply-templates/>
    </xsl:copy>
  </xsl:template>

  <!-- Same as for root -->
  <xsl:template mode="comp" match="tei:publicationStmt">
    <xsl:call-template name="add-publicationStmt"/>
  </xsl:template>
  <xsl:template mode="comp" match="tei:editionStmt/tei:edition">
    <xsl:call-template name="add-edition"/>
  </xsl:template>
  <xsl:template mode="comp" match="tei:meeting">
    <xsl:apply-templates select="."/>
  </xsl:template>
  <xsl:template mode="comp" match="tei:settingDesc/tei:setting">
    <xsl:call-template name="add-setting"/>
  </xsl:template>

  <xsl:template mode="comp" match="tei:encodingDesc">
    <xsl:param name="tagUsages"/>
    <xsl:copy copy-namespaces="no">
      <xsl:apply-templates select="@*"/>
      <xsl:call-template name="add-projectDesc"/>
      <xsl:call-template name="add-tagsDecl">
        <xsl:with-param name="tagUsages" select="$tagUsages"/>
      </xsl:call-template>
    </xsl:copy>
  </xsl:template>

  <!-- link utterance with person -->
  <xsl:template mode="comp" match="tei:u">
    <xsl:variable name="id" select="@xml:id"/>
    <xsl:variable name="speaker" select="$speaker-person//*:item[@utterance = $id]"/>
    <xsl:copy copy-namespaces="no">
      <xsl:apply-templates select="@*[not(name()='ana' or name()='who')]" mode="comp" />
      <xsl:choose>
        <xsl:when test="$speaker">
          <xsl:attribute name="who" select="replace(concat('#',$speaker/@who),'##*','#')"/>
          <xsl:if test="not(@ana = $speaker/@ana)">
            <xsl:message select="concat('INFO: changing speaker type ',@xml:id,'(',@who,'|',$speaker/@who,') ',@ana,' to ',$speaker/@ana)"/>
         </xsl:if>
          <xsl:attribute name="ana" select="$speaker/@ana"/>
        </xsl:when>
        <xsl:otherwise>
          <!-- set guest role if speaker is unknown -->
          <xsl:attribute name="ana">#guest</xsl:attribute>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:apply-templates mode="comp"/>
    </xsl:copy>
  </xsl:template>

  <!-- Take care of syntactic words -->
  <xsl:template mode="comp" match="tei:w[tei:w]">
    <xsl:choose>
      <xsl:when test="tei:w[2]">
        <xsl:copy>
          <xsl:apply-templates mode="comp" select="@*"/>
          <xsl:apply-templates mode="comp"/>
        </xsl:copy>
      </xsl:when>
      <!-- Bad syntactic word with just one word, like:
           <w xml:id="ParlaMint-IT_2013-06-25-LEG17-Sed-50.seg160.23.39-39">gli
             <w xml:id="ParlaMint-IT_2013-06-25-LEG17-Sed-50.seg160.23.39"
                norm="gli"
                lemma="il"
                pos="RD"
                msd="UPosTag=DET|Definite=Def|Gender=Masc|Number=Plur|PronType=Art"/>
           </w>
      -->
      <xsl:otherwise>
        <xsl:message select="concat('WARN ', /tei:TEI/@xml:id,
                             ': removing useless syntactic word ', @xml:id)"/>
        <xsl:copy>
          <xsl:apply-templates mode="comp" select="tei:w/@*[name() != 'norm']"/>
          <xsl:value-of select="normalize-space(.)"/>
        </xsl:copy>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template mode="comp" match="tei:pc/@lemma"/><!-- remove lemma from punctation -->
  <xsl:template mode="comp" match="tei:linkGrp[@type='UD-SYN']/tei:link/@ana[ends-with(.,'_sp')]">
    <xsl:attribute name="ana" select="concat(substring-before(.,'_sp'),'_pred')"/>
  </xsl:template>

  <!-- Remove leading, trailing and multiple spaces -->
  <xsl:template mode="comp" match="text()[normalize-space(.)]">
    <xsl:variable name="str" select="replace(., '\s+', ' ')"/>
    <xsl:choose>
      <xsl:when test="(not(preceding-sibling::tei:*) and matches($str, '^ ')) and
                      (not(following-sibling::tei:*) and matches($str, ' $'))">
        <xsl:value-of select="replace($str, '^ (.+?) $', '$1')"/>
      </xsl:when>
      <xsl:when test="not(preceding-sibling::tei:*) and matches($str, '^ ')">
        <xsl:value-of select="replace($str, '^ ', '')"/>
      </xsl:when>
      <xsl:when test="not(following-sibling::tei:*) and matches($str, ' $')">
        <xsl:value-of select="replace($str, ' $', '')"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$str"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Finalizing ROOT -->

  <xsl:template match="*">
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <xsl:apply-templates/>
    </xsl:copy>
  </xsl:template>
  <xsl:template match="@*">
    <xsl:copy/>
  </xsl:template>

  <xsl:template match="tei:teiCorpus">
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <xsl:apply-templates select="tei:*"/>
      <xsl:for-each select="xi:include">
        <xsl:sort select="@href"/>
        <xsl:variable name="href" select="@href"/>
        <xsl:variable name="new-href" select="$docs/tei:item[./tei:xi-orig/text() = $href]/tei:xi-new/text()"/>
        <xsl:message select="concat('INFO: Fixing xi:include: ',$href,' ',$new-href)"/>
        <xsl:copy>
          <xsl:attribute name="href" select="$new-href"/>
        </xsl:copy>
      </xsl:for-each>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="tei:teiCorpus/@xml:id">
    <xsl:attribute name="xml:id">
      <xsl:value-of select="concat(.,$suff)"/>
    </xsl:attribute>
  </xsl:template>

  <xsl:template match="tei:teiHeader">
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <fileDesc>
        <xsl:element name="titleStmt" xmlns="http://www.tei-c.org/ns/1.0">
          <title type="main" xml:lang="en">Ukrainian parliamentary corpus ParlaMint-UA [ParlaMint<xsl:value-of select="$suff"/>]</title>
          <title type="main" xml:lang="uk">>Корпус Верховної Ради України ParlaMint-UA [ParlaMint<xsl:value-of select="$suff"/>]</title>
          <title type="sub" xml:lang="en">Ukrainian parliament <xsl:value-of select="concat($corpusFrom,' - ',$corpusTo)"/></title>
          <title type="sub" xml:lang="uk">Корпус стенограм Верховної Ради України за період з <xsl:value-of select="concat($corpusFrom,' по ',$corpusTo)"/></title>
          <xsl:for-each select="distinct-values($terms//tei:meeting/@n)">
            <xsl:sort select="."/>
            <xsl:variable name="term" select="."/>
            <xsl:apply-templates select="($terms//tei:meeting[@n=$term])[1]"/>
          </xsl:for-each>
          <xsl:call-template name="add-respStmt"/>
          <xsl:call-template name="add-funder"/>
        </xsl:element>
        <editionStmt>
          <xsl:call-template name="add-edition"/>
        </editionStmt>
        <extent>
          <xsl:call-template name="add-measure-speeches">
            <xsl:with-param name="quantity" select="sum($speeches/tei:item)"/>
          </xsl:call-template>
          <xsl:call-template name="add-measure-words">
            <xsl:with-param name="quantity" select="sum($words/tei:item)"/>
          </xsl:call-template>
        </extent>
        <xsl:call-template name="add-publicationStmt"/>
        <sourceDesc>
          <bibl>
            <xsl:call-template name="add-bibl-title"/>
            <idno type="URI" subtype="parliament">https://www.rada.gov.ua/meeting/stenogr/</idno>
            <date from="{$corpusFrom}" to="{$corpusTo}"><xsl:value-of select="concat($corpusFrom,' - ',$corpusTo)"/></date>
          </bibl>
        </sourceDesc>
      </fileDesc>
      <encodingDesc>
        <xsl:call-template name="add-projectDesc"/>
        <editorialDecl>
          <correction>
            <p xml:lang="en">No correction of source texts was performed.</p>
          </correction>
          <normalization>
            <p xml:lang="en">Spaces were normalized. sequences of dots replaced with a single dot. Adjected notes were joined. Opening and closing parentheses were moved into notes if missing. Regular apostrophes was replaced with soft apostrophes (used in Ukrainian).</p>
          </normalization>
          <hyphenation>
            <p xml:lang="en">No end-of-line hyphens were present in the source.</p>
          </hyphenation>
          <quotation>
            <p xml:lang="en">Quotation marks have been left in the text and are not explicitly marked up.</p>
          </quotation>
          <segmentation>
            <p xml:lang="en">The texts are segmented into utterances (speeches) and segments (corresponding to paragraphs in the source transcription).</p>
          </segmentation>
        </editorialDecl>
        <xsl:call-template name="add-tagsDecl">
          <xsl:with-param name="tagUsages">
            <xsl:for-each select="distinct-values($tagUsages//@gi)">
              <xsl:sort select="."/>
              <xsl:variable name="elem-name" select="."/>
              <tagUsage gi="{$elem-name}" occurs="{sum($tagUsages//*[@gi=$elem-name]/@occurs)}"/>
            </xsl:for-each>
          </xsl:with-param>
        </xsl:call-template>
        <classDecl>
          <xsl:for-each select="$taxonomies/tei:item/text()">
            <xsl:sort select="."/>
            <xsl:variable name="taxonomy" select="."/>
            <xi:include xmlns:xi="http://www.w3.org/2001/XInclude" href="{$taxonomy}"/>
            <xsl:call-template name="copy-file">
              <xsl:with-param name="in" select="concat($inTaxonomiesDir,'/',$taxonomy)"/>
              <xsl:with-param name="out" select="concat($outDir,'/',$corpusDir, '/',$taxonomy)"/>
            </xsl:call-template>
          </xsl:for-each>
        </classDecl>
        <xsl:if test="$type = 'TEI.ana'">
          <listPrefixDef>
            <prefixDef ident="ud-syn" matchPattern="(.+)" replacementPattern="#$1">
               <p xml:lang="en">Private URIs with this prefix point to elements giving their name. In this document they are simply local references into the UD-SYN taxonomy categories in the corpus root TEI header.</p>
            </prefixDef>
          </listPrefixDef>
          <appInfo>
            <application ident="UDPipe" version="2">
               <label>UDPipe 2 (ukrainian-iu-ud-2.10-220711 and russian-syntagrus-ud-2.10-220711 models)</label>
               <desc xml:lang="en">POS tagging, lemmatization and dependency parsing done with UDPipe 2 (<ref target="http://ufal.mff.cuni.cz/udpipe/2">http://ufal.mff.cuni.cz/udpipe/2</ref>) with ukrainian-iu-ud-2.10-220711 and russian-syntagrus-ud-2.10-220711 models</desc>
               <xsl:comment></xsl:comment>
            </application>
          </appInfo>
        </xsl:if>
      </encodingDesc>
      <xsl:apply-templates select="tei:profileDesc"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="tei:profileDesc">
    <xsl:copy>
      <settingDesc>
        <xsl:call-template name="add-setting"/>
      </settingDesc>
      <textClass>
        <catRef scheme="#ParlaMint-taxonomy-parla.legislature" target="#parla.uni"/>
      </textClass>
      <particDesc>
        <xi:include xmlns:xi="http://www.w3.org/2001/XInclude" href="ParlaMint-UA-listOrg.xml"/>
        <xsl:call-template name="copy-file">
          <xsl:with-param name="in" select="$inListOrg"/>
          <xsl:with-param name="out" select="concat($outDir,'/',$corpusDir, '/ParlaMint-UA-listOrg.xml')"/>
        </xsl:call-template>
        <xi:include xmlns:xi="http://www.w3.org/2001/XInclude" href="ParlaMint-UA-listPerson.xml"/>
        <xsl:call-template name="copy-file">
          <xsl:with-param name="in" select="$inListPerson"/>
          <xsl:with-param name="out" select="concat($outDir,'/',$corpusDir, '/ParlaMint-UA-listPerson.xml')"/>
        </xsl:call-template>
      </particDesc>
      <xsl:apply-templates select="tei:langUsage"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="tei:langUsage">
    <xsl:choose>
      <xsl:when test="$type = 'TEI'">
        <xsl:copy-of select="document($url-corpus-ana)/tei:teiCorpus//tei:langUsage"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy>
          <!--xsl:apply-templates select="tei:language[not(@idetn='en')]"/-->
          <xsl:message>TODO: langUsage </xsl:message>
          <xsl:for-each select="$languages/*">
            <xsl:variable name="lang" select="."/>
            <xsl:variable name="usage" select="$langUsage/tei:lang[@n = $lang/@xml:lang]"/>
            <xsl:for-each select="$lang/tei:language">
              <xsl:variable name="translation" select="."/>
              <language xml:lang="{$translation/@xml:lang}" ident="{$lang/@xml:lang}" usage="{$usage}">
                <xsl:value-of select="$translation/text()"/>
              </language>
            </xsl:for-each>
          </xsl:for-each>
          <language xml:lang="en" ident="en" usage="0">english</language>
          <language xml:lang="uk" ident="en" usage="0">aнглійська</language>
        </xsl:copy>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="add-bibl-title">
    <title type="main" xml:lang="uk">Верховна Рада України</title>
  </xsl:template>

  <xsl:template name="add-measure-words">
    <xsl:param name="quantity"/>
    <xsl:call-template name="add-measure">
      <xsl:with-param name="quantity" select="$quantity"/>
      <xsl:with-param name="unit">words</xsl:with-param>
      <xsl:with-param name="en_text">words</xsl:with-param>
      <xsl:with-param name="uk_text">слів</xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="add-measure-speeches">
    <xsl:param name="quantity"/>
    <xsl:call-template name="add-measure">
      <xsl:with-param name="quantity" select="$quantity"/>
      <xsl:with-param name="unit">speeches</xsl:with-param>
      <xsl:with-param name="en_text">speeches</xsl:with-param>
      <xsl:with-param name="uk_text">виступів</xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="add-measure">
    <xsl:param name="quantity"/>
    <xsl:param name="unit"/>
    <xsl:param name="en_text"/>
    <xsl:param name="uk_text"/>
    <xsl:element name="measure">
      <xsl:attribute name="unit" select="$unit"/>
      <xsl:attribute name="quantity" select="$quantity"/>
      <xsl:attribute name="xml:lang">en</xsl:attribute>
      <xsl:value-of select="concat($quantity,' ',$en_text)"/>
    </xsl:element>
    <xsl:element name="measure">
      <xsl:attribute name="unit" select="$unit"/>
      <xsl:attribute name="quantity" select="$quantity"/>
      <xsl:attribute name="xml:lang">uk</xsl:attribute>
      <xsl:value-of select="concat($quantity,' ',$uk_text)"/>
    </xsl:element>
  </xsl:template>

  <xsl:template name="add-tagsDecl">
    <xsl:param name="tagUsages"/>
    <xsl:variable name="context" select="./tei:tagsDecl/tei:namespace[@name='http://www.tei-c.org/ns/1.0']"/>
    <xsl:element name="tagsDecl">
      <xsl:element name="namespace">
        <xsl:attribute name="name">http://www.tei-c.org/ns/1.0</xsl:attribute>
        <xsl:for-each select="distinct-values(($tagUsages//@gi,$context//@gi))">
          <xsl:sort select="."/>
          <xsl:variable name="elem-name" select="."/>
          <xsl:copy-of copy-namespaces="no" select="$tagUsages//*:tagUsage[@gi=$elem-name]"/>
        </xsl:for-each>
      </xsl:element>
    </xsl:element>
  </xsl:template>

  <xsl:template name="add-respStmt">
    <respStmt>
      <persName ref="https://orcid.org/0000-0001-7953-8783">Matyáš Kopp</persName>
      <resp xml:lang="en">Data retrieval</resp>
      <resp xml:lang="uk">Збирання даних</resp>
      <resp xml:lang="en">TEI XML corpus encoding</resp>
      <resp xml:lang="uk">Програмування корпусу у форматі TEI XML</resp>
      <xsl:if test="$type = 'TEI.ana'">
        <resp xml:lang="en">Linguistic annotation</resp>
        <resp xml:lang="uk">Мовна розмітка</resp>
      </xsl:if>
    </respStmt>
    <xsl:element name="respStmt">
      <persName>Anna Kryvenko</persName>
      <resp xml:lang="en">Manual metadata retrieval</resp>
      <resp xml:lang="uk">Ручне збирання метаданих</resp>
      <resp xml:lang="en">Translations</resp>
      <resp xml:lang="uk">Переклад</resp>
    </xsl:element>
  </xsl:template>

  <xsl:template name="add-funder">
    <funder>
      <orgName xml:lang="en">CLARIN ERIC</orgName>
    </funder>
    <funder>
      <orgName xml:lang="en">Slovenian Research Agency</orgName>
      <orgName xml:lang="uk">Державне дослідницьке агентство Республіки Словенія</orgName>
    </funder>
  </xsl:template>

  <xsl:template name="add-setting">
    <setting>
      <name type="org">Верховна Рада України</name>
      <name type="address">вулиця Михайла Грушевського, 5</name>
      <name type="city">Київ</name>
      <name key="UA" type="country">Україна</name>
      <xsl:choose>
        <xsl:when test="./tei:date[parent::tei:setting]/@when">
          <xsl:apply-templates select="./tei:date"/>
        </xsl:when>
        <xsl:otherwise>
          <date from="{$corpusFrom}" to="{$corpusTo}"><xsl:value-of select="concat($corpusFrom,' - ',$corpusTo)"/></date>
        </xsl:otherwise>
      </xsl:choose>
    </setting>
  </xsl:template>


  <xsl:template name="add-edition">
    <edition><xsl:value-of select="$version"/></edition>
  </xsl:template>

  <xsl:template name="add-publicationStmt">
    <publicationStmt>
      <publisher>
        <orgName xml:lang="en">CLARIN research infrastructure</orgName>
        <orgName xml:lang="uk">Дослідницька інфраструктура CLARIN</orgName>
        <ref target="https://www.clarin.eu/">www.clarin.eu</ref>
      </publisher>
      <idno type="URI" subtype="handle">http://hdl.handle.net/11356/XXXX</idno>
      <availability status="free">
        <licence>http://creativecommons.org/licenses/by/4.0/</licence>
        <p xml:lang="en">This work is licensed under the <ref target="http://creativecommons.org/licenses/by/4.0/">Creative Commons Attribution 4.0 International License</ref>.</p>
        <p xml:lang="uk">Цей твір ліцензовано на умовах <ref target="http://creativecommons.org/licenses/by/4.0/">"Міжнародної ліцензії Creative Commons 4.0 із зазначенням авторства"</ref>.</p>
        </availability>
      <date when="{$today}"><xsl:value-of select="$today"/></date>
    </publicationStmt>
  </xsl:template>

  <xsl:template name="add-projectDesc">
    <projectDesc>
      <p xml:lang="uk"><ref target="https://www.clarin.eu/content/parlamint">ParlaMint</ref>  — проєкт, цілями якого є: (1) створення багатомовної групи порівнянних корпусів стенограм парламентських пленарних засідань, які охоплюють період між 2015 роком і серединою 2022 року та які було розроблено відповідно до спільних для всіх інструкцій <ref target="https://clarin-eric.github.io/ParlaMint/">Інструкції щодо програмування ParlaMint</ref>; (2) лінгвістичне анотування корпусів текстів та їх машинний переклад англійською мовою; (3) забезпечення вільного доступу до корпусів через конкордансери; і (4) створення на основі корпусних даних варіантів використання в галузях політичних наук і цифрових гуманітарних наук.</p>
      <p xml:lang="en"><ref target="https://www.clarin.eu/content/parlamint">ParlaMint</ref> is a project that aims to (1) create a multilingual set of comparable corpora of parliamentary proceedings uniformly encoded according to the <ref target="https://clarin-eric.github.io/ParlaMint/">ParlaMint encoding guidelines</ref>, covering the period from 2015 to mid-2022; (2) add linguistic annotations to the corpora and machine-translate them to English; (3) make the corpora available through concordancers; and (4) build use cases in Political Sciences and Digital Humanities based on the corpus data.</p>
    </projectDesc>
  </xsl:template>
</xsl:stylesheet>
