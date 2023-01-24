<?xml version='1.0' encoding='UTF-8'?>
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  xmlns="http://www.tei-c.org/ns/1.0"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:mk="http://ufal.mff.cuni.cz/matyas-kopp"
  exclude-result-prefixes="tei xs mk">

  <xsl:import href="ParlaMint-UA-lib.xsl"/>
  <xsl:output method="xml" indent="yes"/>

  <xsl:param name="person"/>

  <xsl:variable name="person-table">
    <xsl:call-template name="read-tsv">
      <xsl:with-param name="file" select="$person"/>
    </xsl:call-template>
  </xsl:variable>

  <xsl:variable name="newPerson">
    <xsl:message>TODO newPerson</xsl:message>
    <xsl:for-each select="$gov-person/table/row">
      <xsl:variable name="person" select="."/>
      <person>
        <xsl:variable name="id" select="$person/col[@name='PersonID']"/>
        <xsl:attribute name="xml:id" select="$id"/>
        <xsl:attribute name="n">9999</xsl:attribute>
        <xsl:variable name="forename" select="$person/col[@name='Forename']"/>
        <xsl:variable name="patronymic" select="$person/col[@name='Patronymic']"/>
        <xsl:variable name="surname" select="$person/col[@name='Surname']"/>
        <persName>
          <xsl:if test="$forename">
            <forename>
              <xsl:value-of select="$forename"/>
            </forename>
          </xsl:if>
          <xsl:if test="$patronymic">
            <surname type="patronym">
              <xsl:value-of select="$patronymic"/>
            </surname>
          </xsl:if>
          <xsl:if test="$surname">
            <surname>
              <xsl:value-of select="$surname"/>
            </surname>
          </xsl:if>
        </persName>
        <xsl:variable name="sex" select="$person/col[@name='Sex']"/>
        <xsl:if test="$sex">
          <sex>
            <xsl:attribute name="value" select="$sex"/>
          </sex>
        </xsl:if>
        <xsl:variable name="birth" select="$person/col[@name='Birth']"/>
        <xsl:if test="$birth">
          <birth when="{$birth}"/>
        </xsl:if>
        <xsl:variable name="idnoW" select="$person/col[@name='urlWiki']"/>
        <xsl:if test="$idnoW">
          <idno type="URI" subtype="wikimedia">
            <xsl:value-of select="$idnoW"/>
          </idno>
        </xsl:if>
          <xsl:for-each select="tokenize($person/col[@name='urlPersonal'],' *; *')">
            <xsl:variable name="idno" select="."/>
            <xsl:if test="$idno">
            <idno type="URI">
              <xsl:attribute name="subtype">
                <xsl:choose>
                  <xsl:when test="contains($idno,'facebook')">facebook</xsl:when>
                  <xsl:when test="contains($idno,'twitter')">twitter</xsl:when>
                  <xsl:otherwise>personal</xsl:otherwise>
                </xsl:choose>
              </xsl:attribute>
              <xsl:value-of select="$idno"/>
            </idno>
          </xsl:if>
       </xsl:for-each>
      </person>
    </xsl:for-each>
  </xsl:variable>

  <xsl:template match="/">
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="tei:listPerson">
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <xsl:variable name="listPerson" select="."/>
      <xsl:for-each select="distinct-values($listPerson/tei:person/@xml:id | $newPerson/tei:person/@xml:id)">
        <xsl:sort select="."/>
        <xsl:variable name="id" select="."/>
        <xsl:variable name="$old" select="$listPerson/tei:person[@xml:id=$id]"/>
        <xsl:variable name="$new" select="$newPerson/tei:person[@xml:id=$id]"/>
        <xsl:choose>
          <xsl:when test="$old"><xsl:apply-templates select="$old"/></xsl:when>
          <xsl:when test="$new"><xsl:apply-templates select="$new"/></xsl:when>
        </xsl:choose>
      </xsl:for-each>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="tei:*">
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <xsl:apply-templates/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="@*">
    <xsl:copy/>
  </xsl:template>
</xsl:stylesheet>