<?xml version="1.0"?>
<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns="http://www.tei-c.org/ns/1.0"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  exclude-result-prefixes="xsl tei xs"
  version="2.0">

  <xsl:param name="outFilePrefix"><xsl:value-of select="base-uri()"/></xsl:param>
  <xsl:param name="lang"/>
  <xsl:param name="tokenize"/>
  <xsl:variable name="tok">
    <xsl:if test="$tokenize">.tok</xsl:if>
  </xsl:variable>
  <xsl:output method="text"/>

  <xsl:variable name="fileIn" select="replace(base-uri(), '.*/', '')"/>
  <xsl:variable name="fileOutTXT" select="concat($outFilePrefix,$tok,'.txt')"/>
  <xsl:variable name="fileOutANN" select="concat($outFilePrefix,$tok,'.ann')"/>


  <xsl:variable name="text">
    <xsl:apply-templates select="/tei:TEI/tei:text//tei:s[not($lang) or ./ancestor-or-self::tei:*[@xml:lang][1]/@xml:lang = $lang]" mode="clean"/>
  </xsl:variable>

  <xsl:template match="/">
    <xsl:value-of select="concat('Processing ', $fileIn,'&#10;')"/>
    <xsl:value-of select="concat('Saving ', $fileOutTXT,'&#10;')"/>
    <xsl:result-document href="{$fileOutTXT}">
      <xsl:apply-templates select="$text/(tei:s|text())" mode="text"/>
    </xsl:result-document>
    <xsl:value-of select="concat('Saving ', $fileOutANN,'&#10;')"/>
    <xsl:result-document href="{$fileOutANN}">
      <xsl:apply-templates select="$text/descendant-or-self::text()[1]" mode="ann">
        <xsl:with-param name="offset">0</xsl:with-param>
        <xsl:with-param name="ident">0</xsl:with-param>
      </xsl:apply-templates>
    </xsl:result-document>
  </xsl:template>

  <xsl:template match="tei:s" mode="clean">
    <xsl:copy>
      <xsl:apply-templates select="tei:*" mode="clean"/>
    </xsl:copy>
    <xsl:text>&#10;</xsl:text>
  </xsl:template>
  <xsl:template match="tei:w | tei:pc" mode="clean">
    <xsl:value-of select="./text()[normalize-space(.)]"/>
    <xsl:if test="(not(@join) or not($tok = '') ) and ./following-sibling::tei:*/descendant-or-self::tei:*[name() = 'pc' or name() = 'w'] ">
      <xsl:text> </xsl:text>
    </xsl:if>
  </xsl:template>
  <xsl:template match="tei:name[@type]" mode="clean">
    <xsl:element name="{@type}">
      <xsl:apply-templates select="tei:*" mode="clean"/>
    </xsl:element>
    <xsl:if test="(not(./descendant::tei:*[name() = 'pc' or name() = 'w'][last()][@join]) or not($tok = '')) and ./following-sibling::tei:*/descendant-or-self::tei:*[name() = 'pc' or name() = 'w']">
      <xsl:text> </xsl:text>
    </xsl:if>
  </xsl:template>

  <xsl:template match="tei:*" mode="clean">
    <xsl:apply-templates select="tei:*" mode="clean"/>
    <xsl:if test="(not(./descendant::tei:*[name() = 'pc' or name() = 'w'][last()][@join]) or not($tok = '')) and ./following-sibling::tei:*/descendant-or-self::tei:*[name() = 'pc' or name() = 'w']">
      <xsl:text> </xsl:text>
    </xsl:if>
  </xsl:template>



  <xsl:template match="tei:s" mode="text">
    <xsl:apply-templates select="text() | * " mode="text"/>
  </xsl:template>
  <xsl:template match="text()" mode="text">
    <xsl:value-of select="."/>
  </xsl:template>
  <xsl:template match="*" mode="text">
    <xsl:apply-templates select="text()" mode="text"/>
  </xsl:template>


  <xsl:template match="text()" mode="ann">
    <xsl:param name="offset"/>
    <xsl:param name="ident"/>
    <xsl:variable name="is-ann" select="./parent::*[not(name() = 's')]"/>
    <xsl:if test="$is-ann">
      <xsltext>T</xsltext>
      <xsl:value-of select="number($ident)+number(1)"/>
      <xsl:text>&#09;</xsl:text>
      <xsl:value-of select="./parent::*/name()"/>
      <xsl:value-of select="concat(' ',$offset,' ',(number($offset) + string-length(.)))"/>
      <xsl:text>&#09;</xsl:text>
      <xsl:value-of select="."/>
      <xsl:text>&#10;</xsl:text>
    </xsl:if>
    <xsl:apply-templates select="./following::text()[1]" mode="ann">
      <xsl:with-param name="offset" select="number($offset) + string-length(.)"/>
      <xsl:with-param name="ident" select="number($ident) + count($is-ann)"/>
    </xsl:apply-templates>

  </xsl:template>


  <xsl:template match="text()|@*|node()"/>
</xsl:stylesheet>
