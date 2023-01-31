<?xml version='1.0' encoding='UTF-8'?>
<xsl:stylesheet version="3.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:ua="http://rada.gov.ua/mps/"
  xmlns:mk="http://ufal.mff.cuni.cz/matyas-kopp"
  xmlns:i="http://www.w3.org/2001/XMLSchema-instance"
  exclude-result-prefixes="#all">


  <xsl:template name="copy-file">
    <xsl:param name="in"/>
    <xsl:param name="out"/>
    <xsl:message select="concat('INFO: copying file ',$in,' ',$out)"/>
    <xsl:result-document href="{$out}" method="text"><xsl:value-of select="unparsed-text($in,'UTF-8')"/></xsl:result-document>
  </xsl:template>

  <xsl:template name="read-csv">
    <xsl:param name="file"/>
    <xsl:param name="source"/>
    <xsl:choose>
      <xsl:when test="unparsed-text-available($file)">
        <xsl:message select="concat('INFO: parsing ',$file)"/>
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
      </xsl:when>
      <xsl:otherwise>
        <xsl:message select="concat('ERROR: missing file ',$file)"/>
      </xsl:otherwise>
    </xsl:choose>
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
    </xsl:if>
  </xsl:template>


  <xsl:template name="read-tsv">
    <xsl:param name="file"/>
    <xsl:param name="source"/>
    <xsl:variable name="text" select="unparsed-text($file, 'UTF-8')"/>
    <xsl:variable name="lines" select="tokenize($text, '&#13;?&#10;')"/>
    <xsl:variable name="header" select="tokenize($lines[1],'&#9;')"/>
    <table>
      <xsl:attribute name="source" select="$source"/>
      <xsl:for-each select="$lines[position() > 1]">
        <xsl:call-template name="read-tsv-row">
          <xsl:with-param name="text" select="."/>
          <xsl:with-param name="n" select="position()"/>
          <xsl:with-param name="header" select="$header"/>
        </xsl:call-template>
      </xsl:for-each>
    </table>
  </xsl:template>

  <xsl:template name="read-tsv-row">
    <xsl:param name="text"/>
    <xsl:param name="n"/>
    <xsl:param name="header"/>
    <xsl:if test="normalize-space($text)">
      <row>
        <xsl:attribute name="n" select="$n"/>
        <xsl:analyze-string select="." regex="(?:&quot;((?:[^&quot;]*|&quot;&quot;)*)&quot;|([^&#9;]*))(?:&#9;|$)">
          <xsl:matching-substring>
            <xsl:variable name="value" select="normalize-space(concat(regex-group(1),regex-group(2)))"/>
            <xsl:if test="$value">
              <col>
                <xsl:variable name="pos" select="position()"/>
                <xsl:attribute name="n" select="$pos"/>
                <xsl:if test="$header[$pos]">
                  <xsl:attribute name="name" select="$header[$pos]"/>
                </xsl:if>
                <xsl:value-of select="replace($value,'&quot;&quot;','&quot;')"/>
              </col>
            </xsl:if>
          </xsl:matching-substring>
        </xsl:analyze-string>
      </row>
    </xsl:if>
  </xsl:template>


  <xsl:template match="table | row | col" mode="multicell">
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <xsl:apply-templates mode="multicell"/>
    </xsl:copy>
  </xsl:template>


  <xsl:template match="text()" mode="multicell">
    <xsl:choose>
      <xsl:when test="not(contains(.,';'))"><xsl:value-of select="."/></xsl:when>
      <xsl:otherwise>
        <xsl:for-each select="tokenize(.,';')">
          <cell>
            <xsl:value-of select="normalize-space(.)"/>
          </cell>
        </xsl:for-each>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:function name="mk:normalize-chars">
    <xsl:param name="text"/>
    <xsl:value-of select="normalize-space(replace($text,'(\w)&#39;&#39;(\w)','$1’$2'))"/>
  </xsl:function>

  <xsl:function name="mk:normalize-fraction">
    <xsl:param name="text"/>
    <xsl:variable name="t1" select="replace($text,'^\s*Депутатська група\s*','','i')"/>
    <xsl:variable name="t2" select="replace($t1,'^\s*Фракці[яї] політичної партії\s*','','i')"/>
    <xsl:variable name="t3" select="replace($t2,'^\s*групи\s*','','i')"/>
    <xsl:variable name="t4" select="replace($t3,'^&quot;Партія\s*','','i')"/>
    <xsl:variable name="t5" select="replace($t4,'\s*у Верховній Раді України[^&quot;]*$','','i')"/>
    <xsl:variable name="t6" select="normalize-space(replace($t5,'-',' - ','i'))"/>
    <xsl:variable name="t7" select="replace($t6,'^&quot;(.*)&quot;$','$1','i')"/>
    <xsl:value-of select="$t7"/>
  </xsl:function>
  <xsl:function name="mk:create-mp-alias">
    <xsl:param name="nodes"/>
    <xsl:value-of select="concat(
                            $nodes[surname/text()][1]/surname/text(),
                            ' ',
                            replace($nodes[firstname/text()][1]/firstname/text(),'^(.).*','$1.'),
                            replace($nodes[patronymic/text()][1]/patronymic/text(),'^(.).*','$1.')
                            )
      "/>
  </xsl:function>
  <xsl:function name="mk:create-parlamint-id">
    <xsl:param name="nodes"/>
    <xsl:param name="decisive-date"/>
    <xsl:variable name="nodes-dec" select="$nodes[./date_oath/text()][xs:date(./date_oath/text()) &lt;= xs:date($decisive-date)]"/>
    <xsl:variable name="nodes-max" select="$nodes-dec[max($nodes-dec/date_oath/xs:date(text())) = xs:date(./date_oath/text())]"/>
    <xsl:value-of select="concat(
                            $nodes-max[firstname/text()][1]/firstname/text(),
                            $nodes-max[patronymic/text()][1]/patronymic/text(),
                            $nodes-max[surname/text()][1]/surname/text(),
                            '.',
                            replace($nodes-max[birthday/text()][1]/birthday/text(), '-.*$','')
                            )
      "/>
  </xsl:function>
</xsl:stylesheet>