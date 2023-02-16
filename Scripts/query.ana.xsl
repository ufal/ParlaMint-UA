<?xml version='1.0' encoding='UTF-8'?>
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  xmlns="http://www.tei-c.org/ns/1.0"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:mk="http://ufal.mff.cuni.cz/matyas-kopp"
  exclude-result-prefixes="tei xs mk">

  <xsl:import href="ParlaMint-UA-lib.xsl"/>
  <xsl:output method="text"/>
  <xsl:param name="actions"/>

  <xsl:variable name="date" select="//tei:setting/tei:date/@when"/>
  <xsl:variable name="source" select="//tei:bibl/tei:idno/text()"/>
  <xsl:template match="/">
    <xsl:variable name="doc" select="."/>
    <xsl:variable name="result">
      <xsl:for-each select="tokenize($actions, ' ')">
        <xsl:choose>
          <xsl:when test=". = 'DEPUTY'">
            <xsl:apply-templates select="$doc//tei:s" mode="DEPUTY"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:message>unknown mode <xsl:value-of select="."/></xsl:message>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:for-each>
    </xsl:variable>
    <xsl:for-each select="$result/*">
      <xsl:sort select="./@sort"/>

      <xsl:value-of select=".//text()"/>
      <xsl:value-of select="concat('&#09;',$date,'&#09;',$source)"/>
      <xsl:text>&#10;</xsl:text>
      <message terminate="yes"/>
    </xsl:for-each>
  </xsl:template>


  <xsl:template match="
    tei:s
      //tei:w[@lemma='заступник']
             [./ancestor::tei:s[1]
                  //tei:w[@pos='PROPN']
                     [contains(@msd,'NameType=Sur')]
              ]" mode="DEPUTY">
    <xsl:variable name="sentence" select="./ancestor::tei:s[1]"/>
    <xsl:variable name="tokens">
      <xsl:apply-templates select="$sentence" mode="TOKENS"/>
    </xsl:variable>

    <xsl:variable name="deputy" select="."/>
    <xsl:variable name="surname" select="$tokens/tei:w[@pos='PROPN'][contains(@msd,'NameType=Sur')][1]"/>
    <xsl:variable name="fullname">
      <xsl:apply-templates select="$surname" mode="get-close-token">
        <xsl:with-param name="direction">prev</xsl:with-param>
        <xsl:with-param name="elem-name">w</xsl:with-param>
        <xsl:with-param name="attr-name">pos</xsl:with-param>
        <xsl:with-param name="attr-equal">PROPN</xsl:with-param>
      </xsl:apply-templates>
      <xsl:copy-of select="$surname"/>
      <xsl:apply-templates select="$surname" mode="get-close-token">
        <xsl:with-param name="direction">next</xsl:with-param>
        <xsl:with-param name="elem-name">w</xsl:with-param>
        <xsl:with-param name="attr-name">pos</xsl:with-param>
        <xsl:with-param name="attr-equal">PROPN</xsl:with-param>
      </xsl:apply-templates>
    </xsl:variable>

    <xsl:variable name="childRole">
      <xsl:apply-templates select="$deputy" mode="CHILDS"/>
    </xsl:variable>
        <xsl:variable name="childRoleNameSubtree">
      <xsl:apply-templates select="$deputy" mode="SUBTREE">
        <xsl:with-param name="attr-name">pos</xsl:with-param>
        <xsl:with-param name="attr-values">ADJ NOUN PROPN</xsl:with-param>
      </xsl:apply-templates>
    </xsl:variable>


    <xsl:variable name="fullrole">
    </xsl:variable>

    <item sort="{$surname}">
      <xsl:value-of select="$surname/text()"/>
      <xsl:text>&#09;</xsl:text>
      <xsl:value-of select="$deputy/text()"/>
      <xsl:text>&#09;</xsl:text>
      <xsl:apply-templates select="$fullname/*" mode="PRINT-tokens"/>
      <xsl:text>&#09;</xsl:text>
      <xsl:apply-templates select="$childRoleNameSubtree/*" mode="PRINT-tokens"/>
      <xsl:text>&#09;</xsl:text>
      <xsl:apply-templates select="$tokens/*" mode="PRINT"/>
    </item>
  </xsl:template>


 <!--
  <xsl:template match="tei:s" mode="DEPUTY">
    <item sort="1">
      <xsl:apply-templates select="." mode="PRINT"/>
    </item>
  </xsl:template>
-->

  <xsl:template match="tei:*" mode="get-close-token">
    <xsl:param name="direction"/>
    <xsl:param name="elem-name"/>
    <xsl:param name="attr-name"/>
    <xsl:param name="attr-equal"/>
    <!-- get first matching token in direction and print it, then call on nextone -->
    <xsl:variable name="tok">
      <xsl:choose>
        <xsl:when test="$direction = 'prev'">
          <xsl:copy-of select="./preceding::tei:*[name() = $elem-name][1]"/>
        </xsl:when>
        <xsl:when test="$direction = 'next'">
          <xsl:copy-of select="./following::tei:*[name() = $elem-name][1]"/>
        </xsl:when>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="token" select="$tok/*[1][@*[name()=$attr-name] = $attr-equal]"/>
    <xsl:if test="$token and $direction = 'next'">
      <xsl:copy-of select="$token"/>
    </xsl:if>
    <xsl:if test="$token">
      <xsl:apply-templates select="$token" mode="get-close-token">
        <xsl:with-param name="direction">prev</xsl:with-param>
        <xsl:with-param name="elem-name">w</xsl:with-param>
        <xsl:with-param name="attr-name">pos</xsl:with-param>
        <xsl:with-param name="attr-equal">PROPN</xsl:with-param>
      </xsl:apply-templates>
    </xsl:if>
    <xsl:if test="$token and $direction = 'prev'">
      <xsl:copy-of select="$token"/>
    </xsl:if>
  </xsl:template>


  <xsl:template match="tei:*" mode="TOKENS">
    <xsl:copy-of select=".//tei:*[name() = 'w' or name() = 'pc']"/>
  </xsl:template>

  <xsl:template match="tei:*" mode="PRINT">
    <xsl:apply-templates select="tei:* | text()" mode="PRINT"/>
  </xsl:template>

  <xsl:template match="text()[normalize-space(.)]" mode="PRINT">
    <xsl:value-of select="concat(normalize-space(.),./parent::*[not(@join)]/string(' '))"/>
  </xsl:template>

  <xsl:template match="tei:*" mode="PRINT-tokens">
    <xsl:value-of select="./text()"/>
    <xsl:if test="./following::*">
      <xsl:text>&#32;</xsl:text>
    </xsl:if>
  </xsl:template>

  <xsl:template match="tei:*" mode="CHILDS">
    <xsl:variable name="headID" select="./@xml:id"/>
    <xsl:copy-of select="./ancestor::tei:s//tei:*[@xml:id][./ancestor::tei:s/tei:linkGrp[@type='UD-SYN']/tei:link/@target/normalize-space(.) = concat('#',$headID,' #',@xml:id)]"/>
  </xsl:template>


  <xsl:template match="tei:*" mode="SUBTREE">
    <xsl:param name="attr-name"/>
    <xsl:param name="attr-values"/>
    <xsl:param name="sentenceID"><xsl:value-of select="./ancestor::tei:s[1]/@xml:id"/></xsl:param>
    <xsl:variable name="headID" select="./@xml:id"/>
    <!-- prev -->
    <xsl:apply-templates select="
               ./preceding::tei:*
                          [@xml:id]
                          [./ancestor::tei:s[1]/@xml:id = $sentenceID]
                          [./ancestor::tei:s/tei:linkGrp[@type='UD-SYN']/tei:link/@target/normalize-space(.) = concat('#',$headID,' #',@xml:id)]
                          [not($attr-name) or contains(concat(' ',$attr-values,' '), concat(' ',@*[name() = $attr-name],' '))]
                          "
                          mode="SUBTREE">
      <xsl:with-param name="attr-name" select="$attr-name"/>
      <xsl:with-param name="attr-values" select="$attr-values"/>
      <xsl:with-param name="sentenceID" select="$sentenceID"/>
    </xsl:apply-templates>
    <!-- head -->
    <xsl:copy-of select="."/>
    <!-- next -->
    <xsl:apply-templates select="
               ./following::tei:*
                          [@xml:id]
                          [./ancestor::tei:s[1]/@xml:id = $sentenceID]
                          [./ancestor::tei:s/tei:linkGrp[@type='UD-SYN']/tei:link/@target/normalize-space(.) = concat('#',$headID,' #',@xml:id)]
                          [not($attr-name) or contains(concat(' ',$attr-values,' '), concat(' ',@*[name() = $attr-name],' '))]
                          "
                          mode="SUBTREE">
      <xsl:with-param name="attr-name" select="$attr-name"/>
      <xsl:with-param name="attr-values" select="$attr-values"/>
      <xsl:with-param name="sentenceID" select="$sentenceID"/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="tei:*"/>
  <xsl:template match="@*"/>
</xsl:stylesheet>