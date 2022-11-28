<?xml version='1.0' encoding='UTF-8'?>
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:xi="http://www.w3.org/2001/XInclude"
  xmlns:mk="http://ufal.mff.cuni.cz/matyas-kopp"
  xmlns:i="http://www.w3.org/2001/XMLSchema-instance"
  exclude-result-prefixes="tei i mk">

  <xsl:param name="speaker-links"/>
  <xsl:param name="in-dir"/>
  <xsl:import href="ParlaMint-UA-lib.xsl"/>
  <xsl:output method="xml" indent="yes"/>

  <xsl:variable name="aliases">
    <xsl:variable name="text" select="unparsed-text($speaker-links, 'UTF-8')"/>
    <xsl:variable name="lines" select="tokenize($text, '&#10;')"/>
    <xsl:for-each select="$lines">
      <xsl:variable name="line" select="tokenize(., '&#9;')"/>
      <xsl:message select="$line"/>
      <xsl:element name="alias">
        <xsl:attribute name="text" select="$line[1]"/>
        <xsl:attribute name="term" select="$line[2]"/>
        <xsl:attribute name="id" select="$line[3]"/>
      </xsl:element>
    </xsl:for-each>
  </xsl:variable>

  <xsl:template match="/">
    <xsl:apply-templates select="/tei:teiCorpus/xi:include" mode="process-component"/>
    <xsl:apply-templates select="@*"/>
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="xi:include" mode="process-component">
    <xsl:variable name="component-infile" select="document(concat($in-dir,'/',@href))" />

    <xsl:result-document href="{@href}" method="xml">
      <xsl:apply-templates select="$component-infile" mode="component"/>
    </xsl:result-document>
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

  <xsl:template match="/" mode="component">
    <xsl:apply-templates select="@*" mode="component"/>
    <xsl:apply-templates mode="component"/>
  </xsl:template>

  <xsl:template match="*" mode="component">
    <xsl:copy>
      <xsl:apply-templates select="@*" mode="component"/>
      <xsl:apply-templates mode="component"/>
    </xsl:copy>
  </xsl:template>
  <xsl:template match="@who" mode="component">
    <xsl:variable name="old-who" select="."/>
    <xsl:variable name="term" select="/tei:TEI/tei:teiHeader//tei:meeting[contains(@ana,'parla.term')]/@n"/>
    <xsl:variable name="new-who" select="$aliases/alias[upper-case(@text)=upper-case($old-who) and @term=$term]/@id"/>
    <xsl:attribute name="who">
      <xsl:choose>
        <xsl:when test="count($new-who) = 1"><xsl:value-of select="concat('#',$new-who)"/></xsl:when>
        <xsl:when test="count($new-who) > 1"><xsl:value-of select="string-join($new-who/concat('#',.),' ')"/></xsl:when>
        <xsl:otherwise><xsl:value-of select="$old-who"/></xsl:otherwise>
      </xsl:choose>
    </xsl:attribute>
  </xsl:template>
  <xsl:template match="@*" mode="component">
    <xsl:copy/>
  </xsl:template>
</xsl:stylesheet>