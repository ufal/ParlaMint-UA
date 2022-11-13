<?xml version='1.0' encoding='UTF-8'?>
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:ua="http://rada.gov.ua/mps/"
  xmlns:i="http://www.w3.org/2001/XMLSchema-instance"
  exclude-result-prefixes="tei ua i">
  <xsl:output method="xml" indent="yes"/>
  <xsl:param name="in-dir"/>
  <xsl:param name="out-dir"/>
  <xsl:param name="terms"/>


  <xsl:variable name="files-mps-data">
    <xsl:for-each select="tokenize($terms, ' ')">
      <xsl:variable name="term" select="."/>
      <xsl:variable name="filename" select="concat($in-dir,'/ogd_mps_skl',$term,'_mps-data.xml')"/>
      <xsl:element name="file">
          <xsl:attribute name="term" select="$term"/>
          <xsl:attribute name="file" select="$filename"/>
          <xsl:copy-of select="document($filename)" />
      </xsl:element>
    </xsl:for-each>
  </xsl:variable>


  <xsl:variable name="mps-data">
    <!-- for each term load data from ogd_mps_skl*_mps-data.xml-->
    <xsl:element name="mps-data">
      <xsl:for-each select="$files-mps-data/file">
        <xsl:variable name="term" select="./@term"/>
        <xsl:element name="term">
          <xsl:attribute name="n" select="$term"/>
          <xsl:apply-templates select="." mode="mps-data"/>
        </xsl:element>
      </xsl:for-each>
    </xsl:element>
  </xsl:variable>

  <xsl:variable name="mp_persons">
    <xsl:element name="mp_persons">
      <xsl:attribute name="source" select="string-join($files-mps-data//@file,' ')"/>
      <xsl:for-each select="distinct-values($mps-data/*/term/mp/@id)">
        <xsl:variable name="mp-id" select="."/>
        <xsl:element name="mp_person">
          <xsl:attribute name="mp-id" select="$mp-id"/>
          <xsl:copy-of select="$mps-data/*/term/mp[@id=$mp-id]"/>
        </xsl:element>
      </xsl:for-each>
    </xsl:element>
  </xsl:variable>

  <xsl:template match="/">
    <xsl:message>process all convacations</xsl:message>

    <!-- xml result -->
    <xsl:variable name="mp-data-path" select="concat($out-dir,'mp-data.xml')"/>
    <xsl:message select="concat('Saving ',$mp-data-path)"/>
    <xsl:result-document href="{$mp-data-path}" method="xml">
      <xsl:copy-of select="$mp_persons"/>
    </xsl:result-document>

    <!-- do some checking -->
    <xsl:variable name="check-path" select="concat($out-dir,'mp-data-check.txt')"/>
    <xsl:message select="concat('Saving ',$check-path)"/>
    <xsl:result-document href="{$check-path}" method="text">
      <xsl:for-each select="$mp_persons/mp_persons/mp_person[count(./mp) > 1]">
        <xsl:variable name="check-result">
          <xsl:call-template name="check"><xsl:with-param name="elem" select="'firstname'"/></xsl:call-template>
          <xsl:call-template name="check"><xsl:with-param name="elem" select="'patronymic'"/></xsl:call-template>
          <xsl:call-template name="check"><xsl:with-param name="elem" select="'surname'"/></xsl:call-template>
          <xsl:call-template name="check"><xsl:with-param name="elem" select="'birthday'"/></xsl:call-template>
          <xsl:call-template name="check"><xsl:with-param name="elem" select="'sex'"/></xsl:call-template>
        </xsl:variable>
        <xsl:if test="normalize-space($check-result)">
          <xsl:value-of select="concat(./@mp-id,':&#10;',$check-result)"/>
        </xsl:if>
      </xsl:for-each>
    </xsl:result-document>

    <!-- tsv result -->
    <!-- person list -->
    <xsl:variable name="person-list-path" select="concat($out-dir,'mp-data-person-list.tsv')"/>
    <xsl:message select="concat('Saving ',$person-list-path)"/>
    <xsl:result-document href="{$person-list-path}" method="text">
      <xsl:text>personID&#9;firstname&#9;patronymic&#9;surname&#9;birthday&#9;sex&#10;</xsl:text>

      <xsl:for-each select="$mp_persons/mp_persons/mp_person">
        <xsl:value-of select="./@mp-id"/><xsl:text>&#9;</xsl:text>
        <xsl:call-template name="print-field"><xsl:with-param name="elem" select="'firstname'"/></xsl:call-template><xsl:text>&#9;</xsl:text>
        <xsl:call-template name="print-field"><xsl:with-param name="elem" select="'patronymic'"/></xsl:call-template><xsl:text>&#9;</xsl:text>
        <xsl:call-template name="print-field"><xsl:with-param name="elem" select="'surname'"/></xsl:call-template><xsl:text>&#9;</xsl:text>
        <xsl:call-template name="print-field"><xsl:with-param name="elem" select="'birthday'"/></xsl:call-template><xsl:text>&#9;</xsl:text>
        <xsl:call-template name="print-field"><xsl:with-param name="elem" select="'sex'"/></xsl:call-template><xsl:text>&#9;</xsl:text>
        <xsl:text>&#10;</xsl:text>
      </xsl:for-each>
    </xsl:result-document>
  </xsl:template>



  <!-- mps-data -->
  <xsl:template match="file" mode="mps-data">
    <xsl:apply-templates select="./ua:ex_mps_info/ua:ex_mps/ua:ex_mp" mode="mps-data-ex"/>
    <xsl:apply-templates select="./ua:mps_info/ua:mps/ua:mp" mode="mps-data-cur"/>
  </xsl:template>

  <xsl:template name="check">
    <xsl:param name="elem"/>
    <xsl:variable name="pers" select="."/>
    <xsl:variable name="values" select="distinct-values(./*/*[local-name()=$elem]/text())"/>
    <xsl:if test="count($values) > 1">
      <xsl:value-of select="concat('&#9;Different values for ',$elem,': ')"/>
      <xsl:for-each select="$values">
        <xsl:variable name="v" select="."/>
        <xsl:value-of select="concat('&#9;',$v,':',string-join($pers/mp[./*[local-name()=$elem]/text() = $v]/@term,'+'))"/>
      </xsl:for-each>
      <xsl:text>&#10;</xsl:text>
    </xsl:if>
  </xsl:template>
  <xsl:template name="print-field">
    <xsl:param name="elem"/>
    <xsl:variable name="pers" select="."/>
    <xsl:variable name="newest" select="$pers/*[@term = max(../*/@term)]/*[local-name()=$elem]/text()"/>
    <xsl:variable name="values" select="distinct-values($pers/*/*[local-name()=$elem]/text()[. != $newest])"/>
    <xsl:value-of select="$newest"/>
    <xsl:if test="$values">
      <xsl:value-of select="concat('(',string-join($values,','),')')"/>
    </xsl:if>
  </xsl:template>






  <xsl:template match="ua:mp" mode="mps-data-cur">
    <xsl:variable name="term" select="ua:convocation"/>
    <xsl:element name="mp">
      <xsl:attribute name="term" select="$term"/>
      <xsl:attribute name="id" select="ua:id"/>
      <xsl:apply-templates select="." mode="mps-data"/>
      <xsl:element name="info"><xsl:value-of select="ua:short_info"/></xsl:element>
      <xsl:apply-templates select="ua:party_id" mode="copy-if-text"/>
      <xsl:variable name="party_id" select="ua:party_id"/>
      <xsl:if test="ua:party_id/text()">
        <xsl:element name="party_name"><xsl:value-of select="$files-mps-data/file[@term=$term]//ua:parties/ua:party[./ua:id/text() = $party_id]/ua:name"/></xsl:element>
      </xsl:if>
      <xsl:apply-templates select="ua:socials" mode="copy-if-text"/>
      <xsl:apply-templates select="ua:post_frs/ua:post_fr" mode="mps-data-cur"><xsl:with-param name="term" select="$term"/></xsl:apply-templates>
    </xsl:element>
  </xsl:template>



  <xsl:template match="ua:ex_mp" mode="mps-data-ex">
    <xsl:element name="mp">
      <xsl:attribute name="term" select="ua:convocation"/>
      <xsl:attribute name="id" select="ua:id"/>
      <xsl:apply-templates select="." mode="mps-data"/>

      <xsl:element name="info"><xsl:value-of select="ua:mps_info_full"/></xsl:element>
      <xsl:apply-templates select="ua:party_num" mode="copy-if-text"/>
      <xsl:apply-templates select="ua:party_name" mode="copy-if-text"/>
    </xsl:element>
  </xsl:template>


  <xsl:template match="ua:ex_mp | ua:mp" mode="mps-data">
    <xsl:apply-templates select="ua:firstname" mode="copy-if-text"/>
    <xsl:apply-templates select="ua:patronymic" mode="copy-if-text"/>
    <xsl:apply-templates select="ua:surname" mode="copy-if-text"/>
    <xsl:apply-templates select="ua:birthday" mode="copy-if-text"/>
    <xsl:element name="sex">
      <xsl:choose>
        <xsl:when test="ua:gender/text() = 1">M</xsl:when>
        <xsl:otherwise>F</xsl:otherwise>
      </xsl:choose>
    </xsl:element>
    <xsl:apply-templates select="ua:date_oath" mode="copy-if-text"/>
    <xsl:apply-templates select="ua:date_finish" mode="copy-if-text"/>
    <xsl:apply-templates select="ua:photo" mode="copy-if-text"/>
    <xsl:apply-templates select="ua:rada_id" mode="copy-if-text"/>
  </xsl:template>

  <xsl:template match="ua:*[text()]" mode="copy-if-text">
    <xsl:copy-of select="." copy-namespaces="false"/>
  </xsl:template>

  <xsl:template match="ua:post_fr" mode="mps-data-cur">
    <xsl:param name="term"/>
    <xsl:variable name="post_id" select="./ua:fr_post_id/text()"/>
    <xsl:variable name="org_id" select="./ua:fr_association_id/text()"/>
    <xsl:variable name="org" select="$files-mps-data/file[@term=$term]//ua:fr_associations/ua:association[./ua:id/text() = $org_id]"/>
    <xsl:element name="membership">
      <xsl:attribute name="type">
        <xsl:choose>
          <xsl:when test="$org/ua:is_fr/text() = 1">fraction</xsl:when>
          <xsl:otherwise>unknown</xsl:otherwise>
        </xsl:choose>
      </xsl:attribute>
      <xsl:attribute name="post_id" select="$post_id"/>
      <xsl:attribute name="org_id" select="$org_id"/>
      <xsl:attribute name="post_name" select="$files-mps-data/file[@term=$term]//ua:fr_posts/ua:post[./ua:id/text() = $post_id]/ua:name"/>
      <xsl:attribute name="org_name" select="$org/ua:name"/>
    </xsl:element>
  </xsl:template>

</xsl:stylesheet>