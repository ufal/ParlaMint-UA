<?xml version='1.0' encoding='UTF-8'?>
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns="http://www.tei-c.org/ns/1.0"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:xi="http://www.w3.org/2001/XInclude"
  xmlns:mk="http://ufal.mff.cuni.cz/matyas-kopp"
  xmlns:i="http://www.w3.org/2001/XMLSchema-instance"
  exclude-result-prefixes="tei i mk xs xi">

  <xsl:param name="in-tei-dir"/>
  <xsl:param name="in-tsv-dir"/>
  <xsl:import href="ParlaMint-UA-lib.xsl"/>
  <xsl:output method="xml" indent="yes"/>


  <xsl:template match="/">
    <xsl:apply-templates select="/tei:teiCorpus/xi:include" mode="process-component"/>
    <xsl:apply-templates select="@*"/>
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="xi:include" mode="process-component">
    <xsl:variable name="component-tei-infile" select="document(concat($in-tei-dir,'/',@href))" />
    <xsl:variable name="tsv-path" select="concat($in-tsv-dir,'/',replace(@href,'\.xml$','.tsv'))" />
    <xsl:variable name="id-lang">
      <xsl:variable name="table">
        <xsl:call-template name="read-tsv">
          <xsl:with-param name="file" select="$tsv-path"/>
        </xsl:call-template>
      </xsl:variable>
      <xsl:for-each select="$table//row">
        <xsl:if test="./col[@name='id']">
          <item sentence="{./col[@name='id']}" language="{./col[@name='language']}"/>
        </xsl:if>
      </xsl:for-each>
    </xsl:variable>
    <xsl:result-document href="{@href}" method="xml">
      <xsl:apply-templates select="$component-tei-infile" mode="component">
        <xsl:with-param name="id-lang" select="$id-lang"/>
      </xsl:apply-templates>
    </xsl:result-document>
  </xsl:template>

  <xsl:template match="/" mode="component">
    <xsl:param name="id-lang"/>
    <xsl:apply-templates select="@*"/>
    <xsl:apply-templates mode="component">
      <xsl:with-param name="id-lang" select="$id-lang"/>
    </xsl:apply-templates>
  </xsl:template>


  <xsl:template match="tei:seg" mode="component">
    <xsl:param name="id-lang"/>
    <xsl:variable name="segId" select="./@xml:id"/>
    <xsl:variable name="childnodes">
      <!--add language to tmpSentence, other elements are coppied-->
      <xsl:for-each select="*|text()">
        <xsl:choose>
          <xsl:when test="local-name() = 'tmpSentence'">
            <!-- add language to sentence -->
            <xsl:variable name="id" select="./@xml:id"/>
            <xsl:variable name="lang" select="$id-lang/tei:item[@sentence=$id]/@language"/>
            <!-- TODO: copy sentence and add language -->
            <xsl:apply-templates select="." mode="add-lang">
              <xsl:with-param name="lang" select="$lang"/>
            </xsl:apply-templates>
          </xsl:when>
          <xsl:when test="node()">
            <xsl:copy-of select="."/>
          </xsl:when><!---->
          <xsl:otherwise>
            <xsl:element name="SPACE" namespace="http://www.tei-c.org/ns/1.0"><xsl:copy-of select="."/></xsl:element>
          </xsl:otherwise><!---->
        </xsl:choose>
      </xsl:for-each>
    </xsl:variable>
    <xsl:variable name="langGroups">
      <xsl:for-each-group select="$childnodes/*" group-starting-with="$childnodes/*[
                position() = 1
                or
                (
                  @xml:lang
                  and
                  not(preceding-sibling::tei:*[@xml:lang][1]/@xml:lang = @xml:lang)
                )]">
        <xsl:element name="tmpLangSeg" namespace="http://www.tei-c.org/ns/1.0">
          <xsl:if test="current-group()[1]/@xml:lang">
            <xsl:attribute name="xml:lang" select="current-group()[1]/@xml:lang"/>
          </xsl:if>
          <xsl:apply-templates select="current-group()" mode="component"/>
        </xsl:element>
      </xsl:for-each-group>
    </xsl:variable>
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <xsl:apply-templates select="$langGroups/*" mode="component">
        <xsl:with-param name="segId" select="$segId"/>
      </xsl:apply-templates>

    </xsl:copy>
  </xsl:template>

  <xsl:template match="tei:tmpLangSeg" mode="component">
    <xsl:param name="segId"/>
    <xsl:copy>
      <xsl:attribute name="xml:id" select="concat($segId,'.lang',position())"/>
      <xsl:apply-templates select="@*"/>
      <xsl:apply-templates/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="tei:tmpSentence | tei:SPACE" mode="component">
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="tei:tmpSentence" mode="add-lang">
    <xsl:param name="lang"/>
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <xsl:attribute name="xml:lang">
        <xsl:choose>
          <xsl:when test="$lang = 'UKRAINIAN'">uk</xsl:when>
          <xsl:when test="$lang = 'RUSSIAN'">ru</xsl:when>
          <xsl:otherwise><xsl:message select="concat('ERROR: unknown language ',$lang,' in ',./@xml:id,':',.)"/></xsl:otherwise>
        </xsl:choose>
      </xsl:attribute>
      <xsl:apply-templates/>
    </xsl:copy>
  </xsl:template>


  <xsl:template match="*" mode="component">
    <xsl:param name="id-lang"/>
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <xsl:apply-templates mode="component">
        <xsl:with-param name="id-lang" select="$id-lang"/>
      </xsl:apply-templates>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="*">
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <xsl:apply-templates/>
    </xsl:copy>
  </xsl:template>
  <xsl:template match="@*">
    <xsl:copy/>
  </xsl:template>

</xsl:stylesheet>