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
      <xsl:variable name="filename" select="concat('ogd_mps_skl',$term,'_mps-data.xml')"/>
      <xsl:element name="file">
          <xsl:attribute name="term" select="$term"/>
          <xsl:attribute name="source" select="$filename"/>
          <xsl:copy-of select="document(concat($in-dir,'/',$filename))" />
      </xsl:element>
    </xsl:for-each>
  </xsl:variable>


  <xsl:variable name="files-mpsTT-data">
    <xsl:for-each select="tokenize($terms, ' ')">
      <xsl:variable name="term" select="."/>
      <xsl:variable name="filename" select="concat('ogd_mps_skl',$term,'_mps0',$term,'-data.xml')"/>
      <xsl:element name="file">
          <xsl:attribute name="term" select="$term"/>
          <xsl:attribute name="source" select="$filename"/>
          <xsl:copy-of select="document(concat($in-dir,'/',$filename))" />
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

  <xsl:variable name="mpsTT-data">
    <!-- for each term load data from ogd_mps_skl*_mps0*-data.xml-->
    <xsl:element name="mpsTT-data">
      <xsl:for-each select="$files-mpsTT-data/file">
        <xsl:variable name="term" select="./@term"/>
        <xsl:element name="term">
          <xsl:attribute name="n" select="$term"/>
          <xsl:apply-templates select="." mode="mpsTT-data"/>
        </xsl:element>
      </xsl:for-each>
    </xsl:element>
  </xsl:variable>

  <xsl:variable name="mp_persons">
    <xsl:element name="mp_persons">
      <xsl:attribute name="source" select="string-join($files-mps-data//@file,' ')"/>
      <xsl:for-each select="distinct-values($mps-data/*/term/mp/@id | $mpsTT-data/*/term/mp/@id)">
        <xsl:variable name="mp-id" select="."/>
        <xsl:element name="mp_person">
          <xsl:attribute name="mp-id" select="$mp-id"/>
          <xsl:for-each select="distinct-values($mps-data/*/term/mp[@id=$mp-id]/@term | $mpsTT-data/*/term/mp[@id=$mp-id]/@term)">
            <xsl:variable name="term" select="."/>
            <xsl:variable name="terms" select="$mps-data/*/term/mp[@id=$mp-id and @term=$term] | $mpsTT-data/*/term/mp[@id=$mp-id and @term=$term]"/>
            <xsl:element name="term">
              <xsl:attribute name="term" select="$term"/>
              <xsl:for-each select="distinct-values($terms/*/local-name())">
                <xsl:sort select="."/>
                <xsl:variable name="elem" select="."/>
                <xsl:call-template name="merge-equal-elements">
                  <xsl:with-param name="elems" select="$terms/*[local-name()=$elem]"/>
                  <xsl:with-param name="name" select="$elem"/>
                </xsl:call-template>
              </xsl:for-each>
            </xsl:element>
          </xsl:for-each>
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
      <xsl:for-each select="$mp_persons/mp_persons/mp_person[count(./term) > 1]">
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

    <!-- stats -->
    <xsl:variable name="stats-path" select="concat($out-dir,'mp-data-stats')"/>
    <xsl:message select="concat('Saving ',$stats-path,'...')"/>
    <xsl:apply-templates select="$mp_persons/mp_persons" mode="stats">
      <xsl:with-param name="path-prefix" select="$stats-path"/>
    </xsl:apply-templates>

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
    <xsl:value-of select="$newest[1]"/>
    <xsl:if test="string-join($values,'')">
      <xsl:value-of select="concat('(',string-join($values,','),')')"/>
    </xsl:if>
  </xsl:template>






  <xsl:template match="ua:mp" mode="mps-data-cur">
    <xsl:variable name="term" select="ua:convocation"/>
    <xsl:element name="mp">
      <xsl:attribute name="term" select="$term"/>
      <xsl:attribute name="id" select="ua:id"/>
      <xsl:attribute name="source" select="./ancestor-or-self::*[@source][1]/@source"/>
      <xsl:apply-templates select="." mode="mps-data"/>
      <xsl:element name="info">
        <xsl:call-template name="add-source"><xsl:with-param name="elem" select="'short_info'"/></xsl:call-template>
        <xsl:value-of select="ua:short_info"/>
      </xsl:element>
      <xsl:apply-templates select="ua:party_id" mode="copy-if-text"/>
      <xsl:variable name="party_id" select="ua:party_id/text()"/>
      <xsl:if test="$party_id">
        <xsl:element name="party_name"><xsl:value-of select="$files-mps-data/file[@term=$term]//ua:parties/ua:party[./ua:id/text() = $party_id]/ua:name"/></xsl:element>
      </xsl:if>
      <xsl:apply-templates select="ua:socials/ua:social/ua:url" mode="copy-if-text"><xsl:with-param name="rename" select="'social_url'"/></xsl:apply-templates>
      <xsl:apply-templates select="ua:post_frs/ua:post_fr" mode="mps-data-cur"><xsl:with-param name="term" select="$term"/></xsl:apply-templates>
    </xsl:element>
  </xsl:template>



  <xsl:template match="ua:ex_mp" mode="mps-data-ex">
    <xsl:element name="mp">
      <xsl:attribute name="term" select="ua:convocation"/>
      <xsl:attribute name="id" select="ua:id"/>
      <xsl:attribute name="source" select="./ancestor-or-self::*[@source][1]/@source"/>
      <xsl:apply-templates select="." mode="mps-data"/>

      <xsl:element name="info">
        <xsl:call-template name="add-source"><xsl:with-param name="elem" select="'mps_info_full'"/></xsl:call-template>
        <xsl:value-of select="ua:mps_info_full"/>
      </xsl:element>
      <xsl:apply-templates select="ua:party_num" mode="copy-if-text"><xsl:with-param name="rename" select="'party_id'"/></xsl:apply-templates>
      <xsl:apply-templates select="ua:party_name" mode="copy-if-text"/>
    </xsl:element>
  </xsl:template>


  <xsl:template match="ua:ex_mp | ua:mp" mode="mps-data">
    <xsl:apply-templates select="ua:firstname" mode="copy-if-text"/>
    <xsl:apply-templates select="ua:patronymic" mode="copy-if-text"/>
    <xsl:apply-templates select="ua:surname" mode="copy-if-text"/>
    <xsl:apply-templates select="ua:birthday" mode="copy-if-text"/>
    <xsl:element name="sex">
      <xsl:call-template name="add-source"><xsl:with-param name="elem" select="'gender'"/></xsl:call-template>
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

  <xsl:template match="*[text()]" mode="copy-if-text">
    <xsl:param name="rename"><xsl:value-of select="local-name()"/></xsl:param>
    <xsl:element name="{$rename}">
      <xsl:call-template name="add-source"><xsl:with-param name="elem" select="local-name()"/></xsl:call-template>
      <xsl:choose>
        <xsl:when test="matches(./text(),'^[0-9]{4}-[01][0-9]-[0123][0-9]T00:00:00$')">
          <xsl:value-of select="replace(./text(), '^(\d\d\d\d-\d\d-\d\d)T.*$', '$1')"/>
        </xsl:when>
        <xsl:otherwise><xsl:value-of select="normalize-space(./text())"/></xsl:otherwise>
    </xsl:choose>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ua:post_fr" mode="mps-data-cur">
    <xsl:param name="term"/>
    <xsl:variable name="post_id" select="./ua:fr_post_id/text()"/>
    <xsl:variable name="org_id" select="./ua:fr_association_id/text()"/>
    <xsl:variable name="org" select="$files-mps-data/file[@term=$term]//ua:fr_associations/ua:association[./ua:id/text() = $org_id]"/>
    <xsl:element name="membership">
      <xsl:call-template name="add-source"><xsl:with-param name="elem" select="local-name()"/></xsl:call-template>
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


  <!-- mpsTT-data -->
  <xsl:template match="file" mode="mpsTT-data">
    <xsl:apply-templates select="./mps/mp" mode="mpsTT-data"/>
  </xsl:template>


  <xsl:template match="mp" mode="mpsTT-data">
    <xsl:element name="mp">
      <xsl:attribute name="term" select="convocation"/>
      <xsl:attribute name="id" select="id"/>
      <xsl:attribute name="source" select="./ancestor-or-self::*[@source][1]/@source"/>

      <xsl:apply-templates select="first_name" mode="copy-if-text"><xsl:with-param name="rename" select="'firstname'"/></xsl:apply-templates>
      <xsl:apply-templates select="second_name" mode="copy-if-text"><xsl:with-param name="rename" select="'patronymic'"/></xsl:apply-templates>
      <xsl:apply-templates select="last_name" mode="copy-if-text"><xsl:with-param name="rename" select="'surname'"/></xsl:apply-templates>
      <xsl:apply-templates select="birthday" mode="copy-if-text"/>
      <xsl:element name="sex">
        <xsl:choose>
          <xsl:when test="gender/text() = 1">M</xsl:when>
          <xsl:otherwise>F</xsl:otherwise>
        </xsl:choose>
      </xsl:element>

      <xsl:apply-templates select="date_begin" mode="copy-if-text"><xsl:with-param name="rename" select="'date_oath'"/></xsl:apply-templates>
      <xsl:apply-templates select="date_end" mode="copy-if-text"><xsl:with-param name="rename" select="'date_finish'"/></xsl:apply-templates>
      <xsl:apply-templates select="party_id" mode="copy-if-text"/>

      <xsl:apply-templates select="party_name" mode="copy-if-text"/>
      <xsl:apply-templates select="photo" mode="copy-if-text"/>
      <xsl:apply-templates select="rada_id" mode="copy-if-text"/>
    </xsl:element>
  </xsl:template>


  <!-- -->
  <xsl:template name="merge-equal-elements">
    <xsl:param name="elems"/>
    <xsl:param name="name"/>
    <xsl:choose>
      <xsl:when test="count(distinct-values($elems/text()))=0"> <!-- membership - no text -->
        <xsl:for-each select="$elems">
          <xsl:copy-of select="."/>
        </xsl:for-each>
      </xsl:when>
      <xsl:when test="count(distinct-values($elems/text()))>1">
        <xsl:for-each select="$elems">
          <xsl:copy-of select="."/>
        </xsl:for-each>
      </xsl:when>
      <xsl:otherwise>
        <xsl:element name="{$name}">
          <xsl:attribute name="source" select="string-join($elems/@source,' ')"/>
          <xsl:copy-of select="$elems[1]/text()"/>
        </xsl:element>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="add-source">
    <xsl:param name="elem"/>
    <xsl:attribute name="source">
      <xsl:value-of select="./ancestor-or-self::*[@source][1]/@source"/>
      <xsl:if test="$elem">
        <xsl:value-of select="concat('#$(//',$elem,')')"/>
      </xsl:if>
    </xsl:attribute>
  </xsl:template>

  <!-- statistics: -->
  <xsl:template match="mp_persons" mode="stats">
  <xsl:param name="path-prefix"/>
  <xsl:variable name="context" select="."/>
  <xsl:result-document href="{concat($path-prefix,'.txt')}" method="text">
    <xsl:text># of different persons:&#9;</xsl:text><xsl:value-of select="count(./mp_person)"/><xsl:text>&#10;</xsl:text>
    <xsl:for-each select="distinct-values($context/mp_person/term/*/local-name())">
      <xsl:sort select="."/>
      <xsl:variable name="elem" select="."/>
      <xsl:text># of different </xsl:text>
      <xsl:value-of select="$elem"/>
      <xsl:text>:&#9;</xsl:text>
      <xsl:value-of select="count(distinct-values($context/mp_person/term/*[local-name() = $elem]))"/>
      <xsl:text>&#10;</xsl:text>
    </xsl:for-each>
  </xsl:result-document>
  <xsl:result-document href="{concat($path-prefix,'-cnt-id-party.tsv')}" method="text">
    <xsl:text>cnt&#9;partyID&#9;partyName&#10;</xsl:text>
    <xsl:for-each select="distinct-values($context/mp_person/term/party_id/text())">
      <xsl:sort select="."/>
      <xsl:variable name="party_id" select="."/>
      <xsl:for-each select="distinct-values($context/mp_person/term[party_id/text() = $party_id]/party_name/text())">
        <xsl:variable name="party_name" select="."/>
        <xsl:value-of select="count($context/mp_person/term[party_id/text() = $party_id and party_name/text() = $party_name])"/>
        <xsl:text>&#9;</xsl:text>
        <xsl:value-of select="$party_id"/>
        <xsl:text>&#9;</xsl:text>
        <xsl:value-of select="$party_name"/>
        <xsl:text>&#10;</xsl:text>
      </xsl:for-each>
    </xsl:for-each>
  </xsl:result-document>
  <xsl:result-document href="{concat($path-prefix,'-cnt-membership.tsv')}" method="text">
    <xsl:text>cnt&#9;orgID&#9;isFraction&#9;term&#9;postID&#9;orgName&#9;postName&#10;</xsl:text>
    <xsl:for-each select="distinct-values($context/mp_person/term/membership/@org_id)">
      <xsl:sort select="."/>
      <xsl:variable name="org_id" select="."/>
      <xsl:for-each select="distinct-values($context/mp_person/term[membership[@org_id = $org_id]]/@term)">
        <xsl:sort select="."/>
        <xsl:variable name="term" select="."/>
        <xsl:for-each select="distinct-values($context/mp_person/term[@term=$term]/membership[@org_id = $org_id]/@post_id)">
          <xsl:sort select="."/>
          <xsl:variable name="post_id" select="."/>
          <xsl:variable name="memberships" select="$context/mp_person/term[@term=$term]/membership[@org_id = $org_id and @post_id = $post_id]"/>
          <xsl:value-of select="count($memberships)"/>
          <xsl:text>&#9;</xsl:text>
          <xsl:value-of select="$org_id"/>
          <xsl:text>&#9;</xsl:text>
          <xsl:value-of select="distinct-values($memberships/@type)"/>
          <xsl:text>&#9;</xsl:text>
          <xsl:value-of select="$term"/>
          <xsl:text>&#9;</xsl:text>
          <xsl:value-of select="$post_id"/>
          <xsl:text>&#9;</xsl:text>
          <xsl:value-of select="distinct-values($memberships/@org_name)"/>
          <xsl:text>&#9;</xsl:text>
          <xsl:value-of select="distinct-values($memberships/@post_name)"/>
          <xsl:text>&#10;</xsl:text>
        </xsl:for-each>
      </xsl:for-each>
    </xsl:for-each>
  </xsl:result-document>
  </xsl:template>
</xsl:stylesheet>