<?xml version='1.0' encoding='UTF-8'?>
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:ua="http://rada.gov.ua/mps/"
  xmlns:mk="http://ufal.mff.cuni.cz/matyas-kopp"
  xmlns:i="http://www.w3.org/2001/XMLSchema-instance"
  exclude-result-prefixes="tei ua i mk">

  <xsl:import href="ParlaMint-UA-lib.xsl"/>

  <xsl:output method="text" indent="yes"/>
  <xsl:param name="in-dir"/>
  <xsl:param name="out-dir"/>
  <xsl:param name="rada-pref">ВРУ</xsl:param>
  <!-- creates ParlaMint-UA-listPerson and ParlaMint-UA-listOrg -->


  <xsl:variable name="mp-data">
    <xsl:copy-of select="document(concat($in-dir,'/mp-data.xml'))" />
  </xsl:variable>

  <xsl:variable name="gov-person">
    <xsl:call-template name="read-tsv">
      <xsl:with-param name="file" select="concat($in-dir,'/gov-person.tsv')"/>
    </xsl:call-template>
  </xsl:variable>

  <xsl:variable name="gov-affiliation">
    <xsl:call-template name="read-tsv">
      <xsl:with-param name="file" select="concat($in-dir,'/gov-affiliation.tsv')"/>
    </xsl:call-template>
  </xsl:variable>

  <xsl:variable name="gov-org">
    <xsl:variable name="gov-o">
      <xsl:call-template name="read-tsv">
        <xsl:with-param name="file" select="concat($in-dir,'/gov-org.tsv')"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:apply-templates select="$gov-o" mode="multicell"/>
  </xsl:variable>

  <xsl:variable name="listPerson-dupl">
    <xsl:element name="listPerson" xmlns="http://www.tei-c.org/ns/1.0">
      <xsl:attribute name="xml:id">ParlaMint-UA-listPerson</xsl:attribute>
      <xsl:attribute name="xml:lang">uk</xsl:attribute>
      <xsl:comment>person list can contain duplicated persons</xsl:comment>
      <!-- mp-data source -->
      <xsl:for-each select="$mp-data/mp_persons/mp_person">
        <xsl:variable name="person" select="."/>
        <xsl:element name="person" xmlns="http://www.tei-c.org/ns/1.0">
          <xsl:attribute name="xml:id" select="$person/@parlamint-id"/>
          <xsl:element name="persName" xmlns="http://www.tei-c.org/ns/1.0">
            <xsl:element name="forename" xmlns="http://www.tei-c.org/ns/1.0">
              <xsl:value-of select="string-join(distinct-values($person/term/firstname),' ')"/>
            </xsl:element>
            <xsl:element name="forename" xmlns="http://www.tei-c.org/ns/1.0">
              <xsl:value-of select="string-join(distinct-values($person/term/patronymic),' ')"/>
            </xsl:element>
            <xsl:element name="surname" xmlns="http://www.tei-c.org/ns/1.0">
              <xsl:value-of select="string-join(distinct-values($person/term/surname),' ')"/>
            </xsl:element>
          </xsl:element>
          <xsl:variable name="sex" select="distinct-values($person/term/sex)[1]"/>
          <xsl:if test="$sex">
            <xsl:element name="sex" xmlns="http://www.tei-c.org/ns/1.0">
              <xsl:attribute name="value" select="$sex"/>
            </xsl:element>
          </xsl:if>
          <xsl:variable name="birth" select="distinct-values($person/term/birthday)[1]"/>
          <xsl:if test="$birth">
            <xsl:element name="birth" xmlns="http://www.tei-c.org/ns/1.0">
              <xsl:attribute name="when" select="$birth"/>
            </xsl:element>
          </xsl:if>
          <xsl:for-each select="$person/term">
            <xsl:variable name="term" select="."/>
            <xsl:variable name="termN" select="$term/@term"/>
            <xsl:variable name="from" select="$term/date_oath"/>
            <xsl:variable name="to" select="$term/date_finish"/>
            <xsl:element name="affiliation" xmlns="http://www.tei-c.org/ns/1.0">
              <xsl:attribute name="ref" select="concat('#',$rada-pref)"/>
              <xsl:attribute name="role">member</xsl:attribute>
              <xsl:if test="$from">
                <xsl:attribute name="from" select="$from"/>
              </xsl:if>
              <xsl:if test="$to">
                <xsl:attribute name="to" select="$to"/>
              </xsl:if>
              <xsl:attribute name="ana" select="concat('#',$rada-pref,'.',$termN)"/>
            </xsl:element>
            <xsl:variable name="partyID" select="$term/party_id"/>
            <xsl:if test="$partyID">

              <xsl:variable name="party" select="$gov-org/table/row[
                                                                    ./col[@name='Role']/text() = 'politicalParty'
                                                                    and ./col[@name='RadaIDs']//text() = $partyID]"/>
              <xsl:choose>
                <xsl:when test="$party">
                  <xsl:element name="affiliation" xmlns="http://www.tei-c.org/ns/1.0">
                    <xsl:attribute name="ref" select="concat('#',$party/col[@name='OrgID'])"/>
                    <xsl:attribute name="role">represent</xsl:attribute>
                    <xsl:if test="$from">
                      <xsl:attribute name="from" select="$from"/>
                    </xsl:if>
                    <xsl:if test="$to">
                      <xsl:attribute name="to" select="$to"/>
                    </xsl:if>
                      <xsl:attribute name="ana" select="concat('#',$rada-pref,'.',$termN)"/>
                  </xsl:element>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:message>unknown political party <xsl:value-of select="$partyID"/>: <xsl:value-of select="$term/party_name"/></xsl:message>
                  <xsl:comment>unknown political party <xsl:value-of select="$partyID"/>: <xsl:value-of select="$term/party_name"/></xsl:comment>
                </xsl:otherwise>
              </xsl:choose>
            </xsl:if>
          </xsl:for-each>
        </xsl:element>
      </xsl:for-each>
      <!-- government(/manual) source -->
      <xsl:for-each select="$gov-person/table/row">
        <xsl:variable name="person" select="."/>
        <xsl:element name="person" xmlns="http://www.tei-c.org/ns/1.0">
          <xsl:variable name="id" select="$person/col[@name='PersonID']"/>
          <xsl:attribute name="xml:id" select="$id"/>
          <xsl:variable name="forename" select="$person/col[@name='Forename']"/>
          <xsl:variable name="patronymic" select="$person/col[@name='Patronymic']"/>
          <xsl:variable name="surname" select="$person/col[@name='Surname']"/>
          <xsl:element name="persName" xmlns="http://www.tei-c.org/ns/1.0">
            <xsl:if test="$forename">
              <xsl:element name="forename" xmlns="http://www.tei-c.org/ns/1.0">
                <xsl:value-of select="$forename"/>
              </xsl:element>
            </xsl:if>
            <xsl:if test="$patronymic">
              <xsl:element name="forename" xmlns="http://www.tei-c.org/ns/1.0">
                <xsl:value-of select="$patronymic"/>
              </xsl:element>
            </xsl:if>
            <xsl:if test="$surname">
              <xsl:element name="surname" xmlns="http://www.tei-c.org/ns/1.0">
                <xsl:value-of select="$surname"/>
              </xsl:element>
            </xsl:if>
          </xsl:element>
          <xsl:variable name="sex" select="$person/col[@name='Sex']"/>
          <xsl:if test="$sex">
            <xsl:element name="sex" xmlns="http://www.tei-c.org/ns/1.0">
              <xsl:attribute name="value" select="$sex"/>
            </xsl:element>
          </xsl:if>
          <xsl:variable name="birth" select="$person/col[@name='Birth']"/>
          <xsl:if test="$birth">
            <xsl:element name="birth" xmlns="http://www.tei-c.org/ns/1.0">
              <xsl:attribute name="when" select="$birth"/>
            </xsl:element>
          </xsl:if>
          <xsl:variable name="idnoW" select="$person/col[@name='urlWiki']"/>
          <xsl:if test="$idnoW">
            <xsl:element name="idno" xmlns="http://www.tei-c.org/ns/1.0">
              <xsl:attribute name="type">URI</xsl:attribute>
              <xsl:attribute name="subtype">wikimedia</xsl:attribute>
              <xsl:value-of select="$idnoW"/>
            </xsl:element>
          </xsl:if>
          <xsl:for-each select="tokenize($person/col[@name='urlPersonal'],' *; *')">
            <xsl:variable name="idno" select="."/>
            <xsl:if test="$idno">
            <xsl:element name="idno" xmlns="http://www.tei-c.org/ns/1.0">
              <xsl:attribute name="type">URI</xsl:attribute>
              <xsl:attribute name="subtype">
                <xsl:choose>
                  <xsl:when test="contains($idno,'facebook')">facebook</xsl:when>
                  <xsl:when test="contains($idno,'twitter')">twitter</xsl:when>
                  <xsl:otherwise>personal</xsl:otherwise>
                </xsl:choose>
              </xsl:attribute>
              <xsl:value-of select="$idno"/>
            </xsl:element>
          </xsl:if>
          </xsl:for-each>
          <xsl:for-each select="$gov-affiliation/table/row[./col[@name='PersonID'] = $id]">
            <xsl:variable name="aff" select="."/>
            <xsl:variable name="org" select="$aff/col[@name='OrgID']"/>
            <xsl:variable name="from" select="$aff/col[@name='From']"/>
            <xsl:variable name="to" select="$aff/col[@name='To']"/>
            <xsl:variable name="event" select="$aff/col[@name='EventID']"/>
            <xsl:variable name="acting" select="$aff/col[@name='Acting']"/>
            <xsl:variable name="role" select="$aff/col[@name='Role']"/>
            <xsl:variable name="role-en" select="$aff/col[@name='RoleName_en']"/>
            <xsl:variable name="role-uk" select="$aff/col[@name='RoleName_uk']"/>

            <xsl:element name="affiliation" xmlns="http://www.tei-c.org/ns/1.0">
              <xsl:attribute name="ref" select="concat('#',$org)"/>
              <xsl:attribute name="role" select="$role"/>
              <xsl:if test="$from">
                <xsl:attribute name="from" select="$from"/>
              </xsl:if>
              <xsl:if test="$to">
                <xsl:attribute name="to" select="$to"/>
              </xsl:if>
              <xsl:if test="$event | $acting">
                <xsl:message>TODO-acting</xsl:message>
                <xsl:attribute name="ana" select="concat('#',$event)"/>
              </xsl:if>
              <xsl:if test="$role-uk">
                <xsl:element name="roleName" xmlns="http://www.tei-c.org/ns/1.0">
                  <xsl:attribute name="xml:lang">uk</xsl:attribute>
                  <xsl:value-of select="$role-uk"/>
                </xsl:element>
              </xsl:if>
              <xsl:if test="$role-en">
                <xsl:element name="roleName" xmlns="http://www.tei-c.org/ns/1.0">
                  <xsl:attribute name="xml:lang">en</xsl:attribute>
                  <xsl:value-of select="$role-en"/>
                </xsl:element>
              </xsl:if>

            </xsl:element>
          </xsl:for-each>
        </xsl:element>
      </xsl:for-each>
      <!-- call in text source -->
    </xsl:element>
  </xsl:variable>

  <xsl:template match="/">
    <!-- xml result -->
    <xsl:variable name="listPerson-path" select="concat($out-dir,'ParlaMint-UA-listPerson.xml')"/>
    <xsl:message select="concat('Saving ',$listPerson-path)"/>
    <xsl:result-document href="{$listPerson-path}" method="xml">
      <xsl:element name="listPerson" xmlns="http://www.tei-c.org/ns/1.0">
        <xsl:attribute name="xml:id">ParlaMint-UA-listPerson</xsl:attribute>
        <xsl:attribute name="xml:lang">uk</xsl:attribute>
        <xsl:for-each select="distinct-values($listPerson-dupl/tei:listPerson/tei:person/@xml:id)">
          <xsl:sort select="."/>
          <xsl:variable name="id" select="."/>
          <xsl:variable name="person" select="$listPerson-dupl/tei:listPerson/tei:person[@xml:id=$id]"/>
          <xsl:element name="person" xmlns="http://www.tei-c.org/ns/1.0">
            <xsl:attribute name="xml:id" select="$id"/>
            <xsl:apply-templates select="$person/tei:persName[1]"/>
            <xsl:apply-templates select="$person/tei:birth[1]"/>
            <xsl:apply-templates select="$person/tei:sex[1]"/>
            <xsl:apply-templates select="$person/tei:idno"/>
            <xsl:apply-templates select="$person/tei:affiliation | $person/comment()"/>
          </xsl:element>
        </xsl:for-each>
      </xsl:element>
    </xsl:result-document>
  </xsl:template>



  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>

</xsl:stylesheet>