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

  <xsl:variable name="gov-guest">
    <xsl:call-template name="read-tsv">
      <xsl:with-param name="file" select="concat($in-dir,'/gov-guest.tsv')"/>
    </xsl:call-template>
  </xsl:variable>

  <xsl:variable name="gov-affiliation">
    <xsl:variable name="gov-a">
      <xsl:call-template name="read-tsv">
        <xsl:with-param name="file" select="concat($in-dir,'/gov-affiliation.tsv')"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:apply-templates select="$gov-a" mode="multicell"/>
  </xsl:variable>

  <xsl:variable name="gov-org">
    <xsl:variable name="gov-o">
      <xsl:call-template name="read-tsv">
        <xsl:with-param name="file" select="concat($in-dir,'/gov-org.tsv')"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:apply-templates select="$gov-o" mode="multicell"/>
  </xsl:variable>

  <xsl:variable name="gov-event">
    <xsl:call-template name="read-tsv">
      <xsl:with-param name="file" select="concat($in-dir,'/gov-event.tsv')"/>
    </xsl:call-template>
  </xsl:variable>

  <xsl:variable name="gov-relation">
    <xsl:call-template name="read-tsv">
      <xsl:with-param name="file" select="concat($in-dir,'/gov-relation.tsv')"/>
    </xsl:call-template>
  </xsl:variable>

  <xsl:variable name="gov-rename">
    <xsl:call-template name="read-tsv">
      <xsl:with-param name="file" select="concat($in-dir,'/gov-rename.tsv')"/>
    </xsl:call-template>
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
          <xsl:variable name="id" select="mk:use-id-or-find-alternative($person/@parlamint-id)"/>
          <!--xsl:variable name="id" select="$person/@parlamint-id"/-->
          <xsl:attribute name="xml:id" select="$id"/>
          <xsl:attribute name="n" select="max($person/term/@term)"/>
          <xsl:element name="persName" xmlns="http://www.tei-c.org/ns/1.0">
            <xsl:element name="forename" xmlns="http://www.tei-c.org/ns/1.0">
              <xsl:value-of select="string-join(distinct-values($person/term/firstname),' ')"/>
            </xsl:element>
            <xsl:variable name="patronym" select="string-join(distinct-values($person/term/patronymic),' ')"/>
            <xsl:if test="$patronym">
              <xsl:element name="surname" xmlns="http://www.tei-c.org/ns/1.0">
                <xsl:attribute name="type">patronym</xsl:attribute>
                <xsl:value-of select="$patronym"/>
              </xsl:element>
            </xsl:if>
            <!--todo multiple names-->
            <xsl:for-each select="distinct-values($person/term/surname)">
              <xsl:element name="surname" xmlns="http://www.tei-c.org/ns/1.0">
                <xsl:value-of select="."/>
              </xsl:element>
            </xsl:for-each>
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
          <xsl:for-each select="$person/term/photo">
            <xsl:element name="figure" xmlns="http://www.tei-c.org/ns/1.0">
              <xsl:element name="graphic" xmlns="http://www.tei-c.org/ns/1.0">
              <xsl:attribute name="url" select="."/>
            </xsl:element>
            </xsl:element>
          </xsl:for-each>
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
                    <xsl:attribute name="role">representative</xsl:attribute>
                    <xsl:if test="$from">
                      <xsl:attribute name="from" select="$from"/>
                    </xsl:if>
                    <xsl:if test="$to">
                      <xsl:attribute name="to" select="$to"/>
                    </xsl:if>
                    <!--  <xsl:attribute name="ana" select="concat('#',$rada-pref,'.',$termN)"/> -->
                  </xsl:element>
                </xsl:when>
                <xsl:when test="$term/party_name[contains(' Самовисування Безпартійний ',.)]">
                  <xsl:comment>from <xsl:value-of select="$from"/> to <xsl:value-of select="$to"/>: <xsl:value-of select="$term/party_name"/></xsl:comment>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:message>WARN: unknown political party <xsl:value-of select="$partyID"/>: <xsl:value-of select="$term/party_name"/></xsl:message>
                  <xsl:comment>unknown political party|<xsl:value-of select="$partyID"/>|<xsl:value-of select="$term/party_name"/>|<xsl:value-of select="$from"/>|<xsl:value-of select="$to"/></xsl:comment>
                </xsl:otherwise>
              </xsl:choose>
            </xsl:if>
            <xsl:for-each select="$term/membership[@type='fraction' and @from and not(@org_name='Позафракційні')]">
              <!-- usually current term -->
              <xsl:variable name="frac_norm_name" select="./@org_name_norm"/>
              <xsl:variable name="frac_name" select="./@org_name"/>
              <xsl:variable name="frac_id" select="$term/membership[@org_name_norm = $frac_norm_name]/@org_id"/>
              <xsl:call-template name="fraction-affiliation">
                <xsl:with-param name="id" select="$frac_id"/>
                <xsl:with-param name="from" select="@from"/>
                <xsl:with-param name="to" select="@to"/>
                <xsl:with-param name="name" select="$frac_name"/>
                <xsl:with-param name="output">comment</xsl:with-param>
              </xsl:call-template>
            </xsl:for-each>
            <!-- if @type='fraction' and @from is missing -->
            <xsl:variable name="fractions-without-timespan" select="$term/membership[@type='fraction' and not(@from) and not(@to)]"/>
            <xsl:if test="not($term/membership[@type='fraction' and @from]) and count($fractions-without-timespan)">
              <xsl:call-template name="fraction-affiliation">
                <xsl:with-param name="from" select="$from"/>
                <xsl:with-param name="to" select="$to"/>
                <xsl:with-param name="name" select="$fractions-without-timespan/@org_name"/>
                <xsl:with-param name="output">comment</xsl:with-param>
              </xsl:call-template>
            </xsl:if>
          </xsl:for-each>

          <!-- inserting affiliations from google sheet: -->
          <xsl:call-template name="insert-GS-affiliations">
            <xsl:with-param name="id" select="$id"/>
          </xsl:call-template>

        </xsl:element>
      </xsl:for-each>
      <!-- government(/manual) source -->
      <xsl:for-each select="$gov-person/table/row[not(./col[@name='Exclude'])] | $gov-guest/table/row[not(./col[@name='Exclude'])]">
        <xsl:variable name="person" select="."/>
        <xsl:element name="person" xmlns="http://www.tei-c.org/ns/1.0">
          <xsl:variable name="id" select="mk:use-id-or-find-alternative($person/col[@name='PersonID'])"/>
          <xsl:attribute name="xml:id" select="$id"/>
          <xsl:attribute name="n">9999</xsl:attribute>
          <xsl:variable name="forename" select="$person/col[@name='Forename']"/>
          <xsl:variable name="patronymic" select="$person/col[@name='Patronymic']"/>
          <xsl:variable name="surname" select="$person/col[@name='Surname']"/>
          <xsl:variable name="occupation" select="$person/col[@name='Occupation']"/>
          <xsl:variable name="country" select="$person/col[@name='Country']"/>
          <xsl:element name="persName" xmlns="http://www.tei-c.org/ns/1.0">
            <xsl:if test="$forename">
              <xsl:for-each select="tokenize($forename,' *; *')">
                <xsl:element name="forename" xmlns="http://www.tei-c.org/ns/1.0">
                  <xsl:value-of select="."/>
                </xsl:element>
              </xsl:for-each>
            </xsl:if>
            <xsl:if test="$patronymic">
              <xsl:element name="surname" xmlns="http://www.tei-c.org/ns/1.0">
                <xsl:attribute name="type">patronym</xsl:attribute>
                <xsl:value-of select="$patronymic"/>
              </xsl:element>
            </xsl:if>
            <xsl:if test="$surname">
              <xsl:for-each select="tokenize($surname,' *; *')">
                <xsl:element name="surname" xmlns="http://www.tei-c.org/ns/1.0">
                  <xsl:value-of select="."/>
                </xsl:element>
              </xsl:for-each>
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
          <xsl:for-each select="tokenize($occupation,' *; *')">
            <xsl:variable name="occlang">
              <xsl:if test="matches(normalize-space(.),'^\[([a-z]*)\]')">
                <xsl:value-of  select="replace(normalize-space(.),'^\[([a-z]*)\].*','$1')"/>
              </xsl:if>
            </xsl:variable>
            <xsl:variable name="occ" select="normalize-space(replace(normalize-space(.),'^\[[a-z]*\]',''))"/>
            <xsl:if test="$occ">
              <xsl:choose>
                <xsl:when test="$occ = 'MP'">
                  <xsl:comment><xsl:value-of select="$occ"/></xsl:comment>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:element name="occupation" xmlns="http://www.tei-c.org/ns/1.0">
                    <xsl:if test="not($occlang='')">
                      <xsl:attribute name="xml:lang" select="$occlang"/>
                    </xsl:if>
                    <xsl:value-of select="$occ"/>
                  </xsl:element>
                </xsl:otherwise>
              </xsl:choose>
            </xsl:if>

          </xsl:for-each>
          <xsl:call-template name="insert-GS-affiliations">
            <xsl:with-param name="id" select="$id"/>
          </xsl:call-template>

        </xsl:element>
      </xsl:for-each>
      <!-- call in text source -->
    </xsl:element>
  </xsl:variable>

  <xsl:template name="insert-GS-affiliations">
    <xsl:param name="id"/>
    <xsl:for-each select="$gov-affiliation/table/row[./col[@name='PersonID'] = $id]">
            <xsl:variable name="aff" select="."/>
            <xsl:variable name="org" select="$aff/col[@name='OrgID']"/>
            <xsl:variable name="from" select="$aff/col[@name='From']"/>
            <xsl:variable name="to" select="$aff/col[@name='To']"/>
            <xsl:variable name="event" select="$aff/col[@name='EventID']//text()"/>
            <xsl:variable name="acting" select="$aff/col[@name='Acting']"/>
            <xsl:variable name="role" select="$aff/col[@name='Role']"/>
            <xsl:variable name="role-en" select="$aff/col[@name='RoleName_en']"/>
            <xsl:variable name="role-uk" select="$aff/col[@name='RoleName_uk']"/>
            <xsl:choose>
              <!--
              <xsl:when test="$role = 'MP'">
                <xsl:message select="concat('INFO: skipping MP role: ',$id,' ',$org,' ',$from,' ',$to,' ***',$role)"/>
              </xsl:when>
            -->
              <xsl:when test="$role = 'MP' and not(matches($from, '^\d{4}-\d{2}-\d{2}$')) and  '3' &lt; substring-after($event,'.')">
                <xsl:message select="concat('INFO: skipping MP role (inaccurate from date): ',$id,' ',$org,' ',$from,' ',$to,' ***',$role)"/>
              </xsl:when>
              <xsl:when test="not($gov-org/table/row[./col[@name='OrgID'] = $org])">
                <xsl:message select="concat('INFO: skipping unknown organization: ',$id,' ***',$org,' ',$from,' ',$to,' ',$role)"/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:element name="affiliation" xmlns="http://www.tei-c.org/ns/1.0">
                  <xsl:attribute name="ref" select="concat('#',$org)"/>
                  <xsl:attribute name="role">
                    <xsl:choose>
                      <xsl:when test="$role = 'MP'">member</xsl:when>
                      <xsl:otherwise><xsl:value-of  select="$role"/></xsl:otherwise>
                    </xsl:choose>
                  </xsl:attribute>
                  <xsl:if test="matches($from, '^\d{4}(-\d{2}-\d{2})?$')">
                    <xsl:attribute name="from" select="$from"/>
                  </xsl:if>
                  <xsl:if test="matches($to, '^\d{4}(-\d{2}-\d{2})?$')">
                    <xsl:attribute name="to" select="$to"/>
                  </xsl:if>
                  <xsl:if test="$event | $acting">
                    <xsl:attribute name="ana" select="string-join(($event/concat('#',.), $acting/concat('#','affiliation.role.acting')),' ')"/>
                  </xsl:if>
                  <xsl:if test="$role-uk">
                    <xsl:element name="roleName" xmlns="http://www.tei-c.org/ns/1.0">
                      <xsl:attribute name="xml:lang">uk</xsl:attribute>
                      <xsl:value-of select="string-join($role-uk//text(),'; ')"/>
                    </xsl:element>
                  </xsl:if>
                  <xsl:if test="$role-en">
                    <xsl:element name="roleName" xmlns="http://www.tei-c.org/ns/1.0">
                      <xsl:attribute name="xml:lang">en</xsl:attribute>
                      <xsl:value-of select="string-join($role-en//text(),'; ')"/>
                    </xsl:element>
                  </xsl:if>
                </xsl:element>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:for-each>
  </xsl:template>

  <xsl:template match="/">
    <!-- xml result -->
    <xsl:variable name="listPerson-path" select="concat($out-dir,'ParlaMint-UA-listPerson.xml')"/>
    <xsl:message select="concat('INFO: Creating ',$listPerson-path)"/>
    <xsl:result-document href="{$listPerson-path}" method="xml">
      <xsl:element name="listPerson" xmlns="http://www.tei-c.org/ns/1.0">
        <xsl:attribute name="xml:id">ParlaMint-UA-listPerson</xsl:attribute>
        <xsl:attribute name="xml:lang">uk</xsl:attribute>
        <xsl:for-each select="distinct-values($listPerson-dupl/tei:listPerson/tei:person/@xml:id)">
          <xsl:sort select="."/>
          <xsl:variable name="id" select="."/>
          <xsl:variable name="person" select="$listPerson-dupl/tei:listPerson/tei:person[@xml:id=$id]"/>
          <xsl:variable name="newest" select="max($person/@n)"/>
          <xsl:variable name="personN" select="$person[@n = $newest or (not($newest) and position()=1)][1]"/>
          <xsl:element name="person" xmlns="http://www.tei-c.org/ns/1.0">
            <xsl:attribute name="xml:id" select="$id"/>
            <xsl:apply-templates select="$personN/tei:persName"/>
            <xsl:apply-templates select="$personN/tei:birth"/>
            <xsl:apply-templates select="$personN/tei:sex"/>
            <xsl:apply-templates select="$person/tei:occupation"/>
            <xsl:apply-templates select="$person/tei:idno"/>
            <xsl:apply-templates select="$person/tei:figure"/>
            <xsl:apply-templates select="$person/tei:affiliation | $person/comment()"/>
          </xsl:element>
        </xsl:for-each>
      </xsl:element>
    </xsl:result-document>
    <xsl:message select="concat('INFO: Saving ',$listPerson-path)"/>

    <!--
    <xsl:result-document href="{$listPerson-path}.DUPL" method="xml">
      <xsl:copy-of select="$listPerson-dupl"/>
    </xsl:result-document>
    -->
    <xsl:variable name="listOrg-path" select="concat($out-dir,'ParlaMint-UA-listOrg.xml')"/>
    <xsl:message select="concat('INFO: Creating ',$listOrg-path)"/>
    <xsl:result-document href="{$listOrg-path}" method="xml">
      <xsl:element name="listOrg" xmlns="http://www.tei-c.org/ns/1.0">
        <xsl:attribute name="xml:id">ParlaMint-UA-listOrg</xsl:attribute>
        <xsl:attribute name="xml:lang">uk</xsl:attribute>
        <xsl:apply-templates select="$gov-org/table/row" mode="print-org"/>
        <xsl:element name="listRelation" xmlns="http://www.tei-c.org/ns/1.0">
          <xsl:apply-templates select="$gov-relation/table/row[col[@name='Relation']]" mode="print-relation"/>
        </xsl:element>
      </xsl:element>
    </xsl:result-document>
    <xsl:message select="concat('INFO: Saving ',$listOrg-path)"/>
  </xsl:template>


  <xsl:template match="tei:persName">
    <xsl:variable name="id" select="../@xml:id"/>
    <xsl:variable name="rename" select="$gov-rename/table/row[./col[@name='PersonID'] = $id]"/>
    <xsl:choose>
      <xsl:when test="count($rename)>0">
        <xsl:for-each select="$rename">
          <xsl:variable name="forename" select="./col[@name='Forename']"/>
          <xsl:variable name="patronymic" select="./col[@name='Patronymic']"/>
          <xsl:variable name="surname" select="./col[@name='Surname']"/>
          <xsl:variable name="from" select="./col[@name='From']"/>
          <xsl:variable name="to" select="./col[@name='To']"/>
          <xsl:element name="persName" xmlns="http://www.tei-c.org/ns/1.0">
            <xsl:if test="$from">
              <xsl:attribute name="from" select="$from"/>
            </xsl:if>
            <xsl:if test="$to">
              <xsl:attribute name="to" select="$to"/>
            </xsl:if>
            <xsl:if test="$forename">
              <xsl:for-each select="tokenize($forename,' *; *')">
                <xsl:element name="forename" xmlns="http://www.tei-c.org/ns/1.0">
                  <xsl:value-of select="."/>
                </xsl:element>
              </xsl:for-each>
            </xsl:if>
            <xsl:if test="$patronymic">
              <xsl:element name="surname" xmlns="http://www.tei-c.org/ns/1.0">
                <xsl:attribute name="type">patronym</xsl:attribute>
                <xsl:value-of select="$patronymic"/>
              </xsl:element>
            </xsl:if>
            <xsl:if test="$surname">
              <xsl:for-each select="tokenize($surname,' *; *')">
                <xsl:element name="surname" xmlns="http://www.tei-c.org/ns/1.0">
                  <xsl:value-of select="."/>
                </xsl:element>
              </xsl:for-each>
            </xsl:if>
          </xsl:element>
        </xsl:for-each>
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy>
          <xsl:apply-templates select="@*|node()"/>
        </xsl:copy>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="tei:affiliation[contains(' head deputyHead minister deputyMinister ', @role)]">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
    <xsl:copy>
      <xsl:apply-templates select="@*[not(name() = 'ana')]" mode="affiliation-member"/>
      <xsl:if test="not(@ref = '#GOV.UA')">
        <xsl:apply-templates select="@ana" mode="affiliation-member"/>
      </xsl:if>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="@role" mode="affiliation-member">
    <xsl:attribute name="role">member</xsl:attribute>
  </xsl:template>

  <xsl:template match="@*[not(name()='role')]" mode="affiliation-member">
    <xsl:copy>
      <xsl:apply-templates select="node()"/>
    </xsl:copy>
  </xsl:template>


  <xsl:template match="row" mode="print-org">
    <xsl:variable name="id" select="./col[@name='OrgID']"/>
    <xsl:variable name="orgName_uk" select="./col[@name='OrgNameFull_uk']"/>
    <xsl:variable name="orgName_en" select="./col[@name='OrgNameFull_en']"/>
    <xsl:variable name="orgName_abb_uk" select="./col[@name='OrgNameAbb_uk']"/>
    <xsl:variable name="orgName_abb_en" select="./col[@name='OrgNameAbb_en']"/>
    <xsl:variable name="from" select="./col[@name='From']"/>
    <xsl:variable name="to" select="./col[@name='To' and matches(text(), '^\d{4}(-\d{2}-\d{2})?')]"/>
    <xsl:variable name="ana" select="./col[@name='Ana']"/>
    <xsl:element name="org" xmlns="http://www.tei-c.org/ns/1.0">
      <xsl:attribute name="xml:id" select="$id"/>
      <xsl:attribute name="role" select="./col[@name='Role']"/>
      <xsl:if test="$ana">
        <xsl:attribute name="ana" select="string-join($ana//text()/concat('#',.),' ')"/>
      </xsl:if>
      <xsl:if test="$orgName_uk">
        <xsl:element name="orgName" xmlns="http://www.tei-c.org/ns/1.0">
          <xsl:attribute name="xml:lang">uk</xsl:attribute>
          <xsl:attribute name="full">yes</xsl:attribute>
          <xsl:value-of select="$orgName_uk"/>
        </xsl:element>
      </xsl:if>
      <xsl:if test="$orgName_en">
        <xsl:element name="orgName" xmlns="http://www.tei-c.org/ns/1.0">
          <xsl:attribute name="xml:lang">en</xsl:attribute>
          <xsl:attribute name="full">yes</xsl:attribute>
          <xsl:value-of select="$orgName_en"/>
        </xsl:element>
      </xsl:if>
      <xsl:if test="$orgName_abb_uk">
        <xsl:element name="orgName" xmlns="http://www.tei-c.org/ns/1.0">
          <xsl:attribute name="xml:lang">uk</xsl:attribute>
          <xsl:attribute name="full">abb</xsl:attribute>
          <xsl:value-of select="$orgName_abb_uk"/>
        </xsl:element>
      </xsl:if>
      <xsl:if test="$orgName_abb_en">
        <xsl:element name="orgName" xmlns="http://www.tei-c.org/ns/1.0">
          <xsl:attribute name="xml:lang">en</xsl:attribute>
          <xsl:attribute name="full">abb</xsl:attribute>
          <xsl:value-of select="$orgName_abb_en"/>
        </xsl:element>
      </xsl:if>
      <xsl:if test="$from | $to">
        <xsl:element name="event" xmlns="http://www.tei-c.org/ns/1.0">
          <xsl:if test="$from">
            <xsl:attribute name="from" select="$from"/>
          </xsl:if>
          <xsl:if test="$to">
            <xsl:attribute name="to" select="$to"/>
          </xsl:if>
          <xsl:element name="label">
            <xsl:attribute name="xml:lang">en</xsl:attribute>
            <xsl:text>existence</xsl:text>
          </xsl:element>
        </xsl:element>
      </xsl:if>
      <xsl:variable name="events" select="$gov-event/table/row[./col[@name='OrgID'] = $id]"/>
      <xsl:if test="$events">
        <xsl:element name="listEvent" xmlns="http://www.tei-c.org/ns/1.0">
          <xsl:for-each select="$events">
            <xsl:sort select="./col[@name='From']"/>
            <xsl:variable name="event" select="."/>
            <xsl:element name="event" xmlns="http://www.tei-c.org/ns/1.0">
              <xsl:attribute name="xml:id" select="$event/col[@name='EventID']"/>
              <xsl:if test="$event/col[@name='From']">
                <xsl:attribute name="from" select="$event/col[@name='From']"/>
              </xsl:if>
              <xsl:if test="$event/col[@name='To' and matches(text(), '^\d{4}(-\d{2}-\d{2})?$')]">
                <xsl:attribute name="to" select="$event/col[@name='To' and matches(text(), '^\d{4}(-\d{2}-\d{2})?$')]"/>
              </xsl:if>
              <xsl:if test="$event/col[@name='Label_uk']">
                <xsl:element name="label">
                  <xsl:attribute name="xml:lang">uk</xsl:attribute>
                  <xsl:value-of select="$event/col[@name='Label_uk']"/>
                </xsl:element>
              </xsl:if>
              <xsl:if test="$event/col[@name='Label_en']">
                <xsl:element name="label">
                  <xsl:attribute name="xml:lang">en</xsl:attribute>
                  <xsl:value-of select="$event/col[@name='Label_en']"/>
                </xsl:element>
              </xsl:if>
            </xsl:element>
          </xsl:for-each>
        </xsl:element>
      </xsl:if>
    </xsl:element>
  </xsl:template>

  <xsl:template match="row" mode="print-relation">
    <xsl:variable name="row" select="."/>
    <xsl:variable name="relation" select="./col[@name='Relation']"/>
    <xsl:choose>
      <xsl:when test="contains(' renaming coalition opposition representing ', concat(' ',$relation,' '))">
        <xsl:element name="relation" xmlns="http://www.tei-c.org/ns/1.0">
          <xsl:attribute name="name" select="$relation"/>
          <xsl:choose>
            <xsl:when test="$relation = 'renaming'">
              <xsl:call-template name="print-relation-attribute"><xsl:with-param name="attr">when</xsl:with-param></xsl:call-template>
              <xsl:call-template name="print-relation-attribute-ref"><xsl:with-param name="attr">active</xsl:with-param></xsl:call-template>
              <xsl:call-template name="print-relation-attribute-ref"><xsl:with-param name="attr">passive</xsl:with-param></xsl:call-template>
            </xsl:when>
            <xsl:when test="$relation = 'coalition'">
              <xsl:call-template name="print-relation-attribute"><xsl:with-param name="attr">from</xsl:with-param></xsl:call-template>
              <xsl:call-template name="print-relation-attribute"><xsl:with-param name="attr">to</xsl:with-param></xsl:call-template>
              <xsl:call-template name="print-relation-attribute-ref"><xsl:with-param name="attr">mutual</xsl:with-param></xsl:call-template>
              <xsl:call-template name="print-relation-attribute-ref"><xsl:with-param name="attr">ana</xsl:with-param></xsl:call-template>
            </xsl:when>
            <xsl:when test="$relation = 'opposition' or $relation = 'representing'">
              <xsl:call-template name="print-relation-attribute"><xsl:with-param name="attr">from</xsl:with-param></xsl:call-template>
              <xsl:call-template name="print-relation-attribute"><xsl:with-param name="attr">to</xsl:with-param></xsl:call-template>
              <xsl:call-template name="print-relation-attribute-ref"><xsl:with-param name="attr">active</xsl:with-param></xsl:call-template>
              <xsl:call-template name="print-relation-attribute-ref"><xsl:with-param name="attr">passive</xsl:with-param></xsl:call-template>
              <xsl:call-template name="print-relation-attribute-ref"><xsl:with-param name="attr">ana</xsl:with-param></xsl:call-template>
            </xsl:when>
          </xsl:choose>
        </xsl:element>
      </xsl:when>
      <xsl:otherwise>
        <xsl:message>WARN: unknown relation|<xsl:value-of select="./text/text()"/></xsl:message>
        <xsl:comment>unknown relation|<xsl:value-of select="./text/text()"/></xsl:comment>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="print-relation-attribute">
    <xsl:param name="attr"/>
    <xsl:variable name="val" select="normalize-space(./col[lower-case(@name)=$attr]/text() )"/>
    <xsl:choose>
      <xsl:when test="matches($val, '^\d{4}(-\d{2}-\d{2})?$') and matches($attr,'^to|when|from$')">
        <xsl:attribute name="{$attr}" select="$val"/>
      </xsl:when>
      <xsl:when test="matches($attr,'^to|when|from$')">
        <!-- date attribute but invalid format -->
      </xsl:when>
      <xsl:when test="$val">
        <xsl:attribute name="{$attr}" select="$val"/>
      </xsl:when>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="print-relation-attribute-ref">
    <xsl:param name="attr"/>
    <xsl:variable name="val" select="normalize-space(
                                     replace(
                                           concat(' ',normalize-space(./col[lower-case(@name)=$attr]/text() )),
                                           ' #*',
                                           ' #'
                                           )
                                        )"/>
    <xsl:if test="$val">
      <xsl:attribute name="{$attr}" select="$val"/>
    </xsl:if>
  </xsl:template>
  <!--
  <xsl:template match="col[contains(' active passive mutual event ',concat(' ',lower-case(./@name),' '))]" mode="print-relation">
    <xsl:attribute name="{lower-case(@name)}" select="string-join(' ',.//text()/concat('#',.))"/>
  </xsl:template>
  <xsl:template match="col[contains(' from to ',concat(' ',@name,' '))]" mode="print-relation">
    <xsl:attribute name="{lower-case(@name)}" select="normalize-space(.)"/>
  </xsl:template>
-->
  <xsl:template match="col" mode="print-relation"/>

  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>


  <xsl:template name="fraction-affiliation">
    <xsl:param name="id"/>
    <xsl:param name="from"/>
    <xsl:param name="to"/>
    <xsl:param name="name"/>
    <xsl:param name="output"/>
    <xsl:variable name="org_by_id" select="$gov-org/table/row[$id and ./col[@name='RadaIDs']//text() = $id]"/>
    <xsl:variable name="org_by_radaName" select="$gov-org/table/row[$name and ./col[@name='RadaName']//text() = $name]"/>
    <xsl:variable name="org_by_fullName" select="$gov-org/table/row[$name and ./col[@name='Role'] = 'parliamentaryGroup' and lower-case(./col[@name='OrgNameFull_uk']) = lower-case($name)]"/>
    <xsl:variable name="ref">
      <xsl:choose>
        <xsl:when test="$org_by_id"><xsl:copy-of select="$org_by_id"/></xsl:when>
        <xsl:when test="$org_by_radaName"><xsl:copy-of select="$org_by_radaName"/></xsl:when>
        <xsl:when test="$org_by_fullName"><xsl:copy-of select="$org_by_fullName"/></xsl:when>
      </xsl:choose>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="count($ref/*) = 1">
        <xsl:call-template name="affiliation-print">
          <xsl:with-param name="ref" select="concat('#', $ref/*/col[@name='OrgID']/text())"/>
          <xsl:with-param name="from" select="$from"/>
          <xsl:with-param name="to" select="$to"/>
          <xsl:with-param name="output" select="$output"/>
        </xsl:call-template>
        <!--
        <xsl:element name="affiliation" xmlns="http://www.tei-c.org/ns/1.0">
          <xsl:attribute name="ref" select="concat('#', $ref/*/col[@name='OrgID']/text())"/>
          <xsl:attribute name="role">member</xsl:attribute>
          <xsl:if test="$from">
            <xsl:attribute name="from" select="$from"/>
          </xsl:if>
          <xsl:if test="$to">
            <xsl:attribute name="to" select="$to"/>
          </xsl:if>
        </xsl:element>
      -->
      </xsl:when>
      <xsl:when test="count($ref/*) > 1">
        <xsl:message terminate="no">TODO multipe affiliations !!!: |<xsl:value-of select="$ref/text()"/>| '<xsl:copy-of select="$ref"/>'</xsl:message>
        <xsl:comment>multiple fraction affiliation at the same time:</xsl:comment>
        <xsl:for-each select="$ref/*">
          <xsl:call-template name="affiliation-print">
            <xsl:with-param name="ref" select="concat('#', ./col[@name='OrgID']/text())"/>
            <xsl:with-param name="from" select="$from"/>
            <xsl:with-param name="to" select="$to"/>
            <xsl:with-param name="output" select="$output"/>
          </xsl:call-template>
          <!--
          <xsl:element name="affiliation" xmlns="http://www.tei-c.org/ns/1.0">
            <xsl:attribute name="ref" select="concat('#', ./col[@name='OrgID']/text())"/>
            <xsl:attribute name="role">member</xsl:attribute>
            <xsl:if test="$from">
              <xsl:attribute name="from" select="$from"/>
            </xsl:if>
            <xsl:if test="$to">
              <xsl:attribute name="to" select="$to"/>
            </xsl:if>
          </xsl:element>
        -->
        </xsl:for-each>
      </xsl:when>
      <xsl:otherwise>
        <!-- no affiliation - organization not found -->
        <xsl:comment>unknown fraction|<xsl:value-of select="$id"/>|<xsl:value-of select="$name"/>|<xsl:value-of select="$from"/>|<xsl:value-of select="$to"/></xsl:comment>
        <xsl:message>WARN: unknown fraction <xsl:value-of select="$id"/>:<xsl:value-of select="$name"/></xsl:message>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="affiliation-print">
    <xsl:param name="ref"/>
    <xsl:param name="from"/>
    <xsl:param name="to"/>
    <xsl:param name="role">member</xsl:param>
    <xsl:param name="output"/>
    <xsl:choose>
      <xsl:when test="$output = 'comment'">
        <xsl:comment>[source=data.rada.gov.ua] affiliation ref="<xsl:value-of select="$ref"/>" role="<xsl:value-of select="$role"/>" from="<xsl:value-of select="$from"/>" to="<xsl:value-of select="$to"/>"/</xsl:comment>
      </xsl:when>
      <xsl:otherwise>
        <xsl:element name="affiliation" xmlns="http://www.tei-c.org/ns/1.0">
          <xsl:attribute name="ref" select="$ref"/>
          <xsl:attribute name="role" select="$role"/>
          <xsl:if test="$from">
            <xsl:attribute name="from" select="$from"/>
          </xsl:if>
          <xsl:if test="$to">
            <xsl:attribute name="to" select="$to"/>
          </xsl:if>
        </xsl:element>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <xsl:function name="mk:use-id-or-find-alternative">
    <xsl:param name="cur-id"/>
    <xsl:variable name="rename-person" select="$gov-rename/table/row[./col[@name='NameID'] = $cur-id ]/col[@name='PersonID']"/>
    <xsl:variable name="mp-person" select="$mp-data/mp_persons/mp_person[./alternative-ids/id/text() = $cur-id]/@parlamint-id"/>
    <xsl:choose>
      <xsl:when test="$rename-person"><xsl:value-of select="$rename-person"/></xsl:when>
      <xsl:when test="count($mp-person) = 1"><xsl:value-of select="$mp-person"/></xsl:when>
      <xsl:when test="count($mp-person) > 1">
        <xsl:message>WARN: repeated alternative id</xsl:message>
        <xsl:value-of select="$cur-id"/>
      </xsl:when>
      <xsl:otherwise><xsl:value-of select="$cur-id"/></xsl:otherwise>
    </xsl:choose>
  </xsl:function>
</xsl:stylesheet>