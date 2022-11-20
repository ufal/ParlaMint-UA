<?xml version='1.0' encoding='UTF-8'?>
<xsl:stylesheet version="3.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:ua="http://rada.gov.ua/mps/"
  xmlns:i="http://www.w3.org/2001/XMLSchema-instance"
  exclude-result-prefixes="#all">


  <xsl:template name="read-csv">
    <xsl:param name="file"/>
    <xsl:param name="source"/>
    <xsl:variable name="text" select="unparsed-text($file, 'UTF-8')"/>
    <xsl:variable name="lines" select="tokenize($text, '&#10;')"/>
    <xsl:variable name="header" select="tokenize($lines[1],',')"/>
    <table>
      <xsl:attribute name="source" select="$source"/>
      <xsl:for-each select="$lines[position() > 1]">
        <xsl:call-template name="read-csv-row">
          <xsl:with-param name="text" select="."/>
          <xsl:with-param name="n" select="position()"/>
          <xsl:with-param name="header" select="$header"/>
        </xsl:call-template>
      </xsl:for-each>
    </table>
  </xsl:template>

  <xsl:template name="read-csv-row">
    <xsl:param name="text"/>
    <xsl:param name="n"/>
    <xsl:param name="header"/>
    <xsl:if test="normalize-space($text)">
      <row>
        <xsl:attribute name="n" select="$n"/>
        <xsl:analyze-string select="." regex="(?:&quot;((?:[^&quot;]*|&quot;&quot;)*)&quot;|([^,]+))(?:,|$)">
          <xsl:matching-substring>
            <col>
              <xsl:variable name="pos" select="position()"/>
              <xsl:attribute name="n" select="$pos"/>
              <xsl:if test="$header[$pos]">
                <xsl:attribute name="name" select="$header[$pos]"/>
              </xsl:if>
              <xsl:value-of select="replace(normalize-space(concat(regex-group(1),regex-group(2))),'&quot;&quot;','&quot;')"/>
            </col>
          </xsl:matching-substring>
<!--
        <xsl:non-matching-substring>
          <xsl:element name="Column_{position()}"/>
        </xsl:non-matching-substring>
-->
        </xsl:analyze-string>
      </row>
    <xsl:text>&#10;</xsl:text>
    </xsl:if>
  </xsl:template>
</xsl:stylesheet>