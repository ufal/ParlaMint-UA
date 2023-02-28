<?xml version='1.0' encoding='UTF-8'?>
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  xmlns="http://www.tei-c.org/ns/1.0"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:mk="http://ufal.mff.cuni.cz/matyas-kopp"
  exclude-result-prefixes="tei xs mk">

  <xsl:import href="ParlaMint-UA-lib.xsl"/>

  <xsl:output method="text"/>
  <xsl:param name="org-list"/>
  <xsl:variable name="refs">
    <xsl:for-each select="tokenize($org-list, ' ')">
      <item><xsl:value-of select="concat('#',.)"/></item>
    </xsl:for-each>
  </xsl:variable>

  <xsl:template match="/">
    <xsl:text>alias&#9;org&#9;id&#9;sex&#9;from&#9;to&#10;</xsl:text>
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="tei:affiliation[@role = 'member'] | tei:person">
    <xsl:variable name="ref" select="@ref"/>
    <xsl:variable name="period">
      <xsl:choose>
        <xsl:when test="$refs/tei:item[text() = $ref] and local-name() = 'affiliation'">
          <xsl:variable name="aff" select="."/>
          <xsl:text>&#9;</xsl:text>
          <xsl:value-of select="substring-after($aff/@ref,'#')"/><xsl:text>&#9;</xsl:text>
          <xsl:value-of select="$aff/parent::tei:person/@xml:id"/><xsl:text>&#9;</xsl:text>
          <xsl:value-of select="$aff/parent::tei:person/tei:sex/@value"/><xsl:text>&#9;</xsl:text>
          <xsl:value-of select="$aff/@from"/><xsl:text>&#9;</xsl:text>
          <xsl:value-of select="$aff/@to"/>
          <xsl:text>&#10;</xsl:text>
        </xsl:when>
        <xsl:when test="local-name() = 'person'">
          <xsl:text>&#9;&#9;</xsl:text>
          <xsl:value-of select="./@xml:id"/>
          <xsl:text>&#9;</xsl:text>
          <xsl:value-of select="./tei:sex/@value"/>
          <xsl:text>&#9;&#9;&#10;</xsl:text>
        </xsl:when>
        <xsl:otherwise/>
      </xsl:choose>
    </xsl:variable>
    <xsl:if test="not($period='')">
      <xsl:for-each select="ancestor-or-self::tei:person[1]/tei:persName">
        <xsl:variable name="persName" select="."/>
        <xsl:for-each select="./tei:surname[not(@type='patronym')]/text()">
        <xsl:value-of select="concat(
                            .,
                            ' ',
                            string-join($persName/tei:forename/replace(text(),'^(.).*','$1.'),''),
                            $persName/tei:surname[@type='patronym']/replace(text(),'^(.).*','$1.'),
                            $period
                            )"/>
        <xsl:value-of select="concat(
                                string-join(
                                  $persName/tei:forename | $persName/tei:surname[@type='patronym'] | .,
                                  ' '),
                                $period
                            )"/>
        </xsl:for-each>
      </xsl:for-each>
    </xsl:if>
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="tei:*">
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="@*"/>
  <xsl:template match="text()"/>


</xsl:stylesheet>