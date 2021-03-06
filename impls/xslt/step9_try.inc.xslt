<?xml version="1.0" encoding="UTF-8"?>
<!-- Step 9: Try -->
<!-- input document must be in the following format -->
<!--
<mal>
    <stdin>...stdin text...</stdin>
    <stdout> ... ignored, omitted ... </stdout>
    <state> contains env and atoms </state>
</mal>
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:fn="http://www.w3.org/2005/02/xpath-functions" xmlns:env="ENV" xmlns:core="CORE" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:map="http://www.w3.org/2005/xpath-functions/map" xmlns:err="http://www.w3.org/2005/xqt-errors" xmlns:MAL="MAL" version="3.0" exclude-result-prefixes="fn xs map env core err MAL">
  <xsl:import href="reader.xslt"/>
  <xsl:import href="printer.xslt"/>
  <xsl:import href="env.xslt"/>
  <xsl:import href="core.xslt"/>
  <xsl:output method="xml" encoding="utf-8" indent="yes"/>
  <xsl:template match="mal" name="rep">
    <xsl:param name="display" select="false()" />
    <xsl:choose>
      <xsl:when test="string(state/env/@data) = ''">
        <xsl:variable name="argv">
          <malval kind="list">
            <lvalue>
              <xsl:for-each select="argv/arg/text()">
                <malval kind="string" value="{.}"/>
              </xsl:for-each>
            </lvalue>
          </malval>
        </xsl:variable>
        <xsl:variable name="vstate">
          <mal>
            <state>
              <env data="{env:serialise(env:empty() =&gt; env:bind-all(core:ns()/@name, core:ns()) =&gt; env:set('*ARGV*', $argv) =&gt; env:toReplEnv())}"/>
              <atoms/>
            </state>
            <stdin>(do (def! not (fn* (a) (if a false true))) (def! load-file (fn* (f) (eval (read-string (str "(do " (slurp f) "\nnil)"))))) (defmacro! cond (fn* (&amp; xs) (if (&gt; (count xs) 0) (list 'if (first xs) (if (&gt; (count xs) 1) (nth xs 1) (throw "odd number of forms to cond")) (cons 'cond (rest (rest xs))))))))</stdin>
          </mal>
        </xsl:variable>
        <xsl:variable name="new-state">
          <xsl:for-each select="$vstate/mal">
            <xsl:call-template name="rep"/>
          </xsl:for-each>
        </xsl:variable>
        <xsl:variable name="state-v">
          <xsl:sequence select="$new-state/mal/state"/>
          <xsl:sequence select="stdin"/>
        </xsl:variable>
        <xsl:for-each select="$state-v">
          <xsl:call-template name="rep">
            <xsl:with-param name="display" select="$display"/>
          </xsl:call-template>
        </xsl:for-each>
      </xsl:when>
      <xsl:otherwise>
        <mal>
          <xsl:variable name="env" as="map(*)">
            <xsl:sequence select="env:deserialise(state/env/@data)"/>
          </xsl:variable>
          <xsl:sequence select="stdin"/>
          <xsl:variable name="_read">
            <xsl:call-template name="READ"/>
          </xsl:variable>
          <xsl:variable name="_eval">
            <xsl:for-each select="$_read">
              <xsl:call-template name="EVAL">
                <xsl:with-param name="env" select="$env"/>
              </xsl:call-template>
            </xsl:for-each>
          </xsl:variable>
          <xsl:for-each select="$_eval">
            <xsl:variable name="_print">
              <xsl:variable name="data">
                <xsl:sequence select="data/value"/>
                <xsl:sequence select="atoms[1]"/>
              </xsl:variable>
              <xsl:for-each select="$data">
                <xsl:call-template name="PRINT"/>
              </xsl:for-each>
            </xsl:variable>
            <xsl:if test="$display">
              <xsl:message>
                <request kind="display" value="{$_print}"/>
              </xsl:message>
            </xsl:if>
            <state>
              <env data="{env/@data}"/>
              <xsl:sequence select="atoms[1]"/>
            </state>
          </xsl:for-each>
        </mal>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <xsl:template name="PRINT">
    <xsl:variable name="str">
      <xsl:call-template name="malprinter-pr_str">
        <xsl:with-param name="readably" select="true()"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:value-of select="$str"/>
  </xsl:template>
  <xsl:template name="eval_ast">
    <xsl:param name="env"/>
    <xsl:param name="atoms"/>
    <xsl:choose>
      <xsl:when test="value/malval/@kind = 'symbol'">
        <xsl:variable name="val">
          <xsl:sequence select="env:get($env, value/malval/@value)"/>
        </xsl:variable>
        <value>
          <xsl:sequence select="$val"/>
        </value>
      </xsl:when>
      <xsl:when test="value/malval/@kind = 'list' or value/malval/@kind = 'vector' or value/malval/@kind = 'hash'">
        <xsl:variable name="myctx">
          <xsl:iterate select="value/malval/lvalue/malval">
            <xsl:param name="atoms" select="$atoms"/>
            <xsl:param name="xctx" select="()"/>
            <xsl:on-completion>
              <xsl:sequence select="$xctx/value/malval"/>
              <xsl:sequence select="$atoms"/>
            </xsl:on-completion>
            <xsl:variable name="ctx">
              <value>
                <xsl:sequence select="."/>
              </value>
              <xsl:sequence select="$atoms"/>
            </xsl:variable>
            <xsl:variable name="xctxy">
              <xsl:for-each select="$ctx">
                <xsl:variable name="val">
                  <xsl:call-template name="EVAL">
                    <xsl:with-param name="env" select="$env"/>
                    <xsl:with-param name="encode-env" select="false()"/>
                  </xsl:call-template>
                </xsl:variable>
                <xsl:sequence select="$val/data/value"/>
                <xsl:sequence select="$val/atoms"/>
              </xsl:for-each>
            </xsl:variable>
            <xsl:next-iteration>
              <xsl:with-param name="atoms" select="$xctxy/atoms"/>
              <xsl:with-param name="xctx" select="$xctx, $xctxy"/>
            </xsl:next-iteration>
          </xsl:iterate>
        </xsl:variable>
        <value>
          <malval kind="{value/malval/@kind}">
            <lvalue>
              <xsl:sequence select="$myctx/malval"/>
            </lvalue>
          </malval>
        </value>
        <xsl:sequence select="$myctx/atoms"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="."/>
        <xsl:sequence select="$atoms"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <xsl:template name="call-function">
    <xsl:param name="func"/>
    <xsl:param name="args"/>
    <xsl:param name="env"/>
    <xsl:variable name="res">
      <xsl:choose>
        <xsl:when test="$func/malval/@kind = 'userfunction'">
          <xsl:call-template name="uapply">
            <xsl:with-param name="func" select="$func"/>
            <xsl:with-param name="args" select="$args"/>
            <xsl:with-param name="env" select="$env"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:otherwise>
          <xsl:call-template name="core-apply">
            <xsl:with-param name="func" select="$func"/>
            <xsl:with-param name="args" select="$args"/>
          </xsl:call-template>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:sequence select="$res/value"/>
    <xsl:choose>
      <xsl:when test="$res/atoms">
        <xsl:sequence select="$res/atoms[1]"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="atoms"/>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:choose>
      <xsl:when test="$res/env">
        <xsl:sequence select="$res/env"/>
      </xsl:when>
      <xsl:otherwise>
        <env data="{$env =&gt; env:serialise()}"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <!-- uapply[env, fn, args] -->
  <xsl:template name="uapply">
    <xsl:param name="func"/>
    <xsl:param name="args"/>
    <xsl:param name="env"/>
    <xsl:variable name="nenv" select="$env =&gt; env:hier(env:deserialise($func/malval/env/@data)) =&gt; env:close-with-binds($func/malval/binds/malval/@value, $args/value/malval/lvalue/malval)"/>
    <xsl:variable name="body">
      <value>
        <xsl:sequence select="$func/malval/body/malval"/>
      </value>
      <xsl:sequence select="atoms[1]"/>
    </xsl:variable>
    <xsl:variable name="result">
      <xsl:for-each select="$body">
        <xsl:call-template name="EVAL">
          <xsl:with-param name="env" select="$nenv"/>
        </xsl:call-template>
      </xsl:for-each>
    </xsl:variable>
    <xsl:sequence select="$result/data/value"/>
    <env data="{env:serialise(env:swap-replEnv($env, env:deserialise($result/env/@data) =&gt; env:replEnv()))}"/>
    <xsl:sequence select="$result/atoms[1]"/>
  </xsl:template>
  <xsl:template name="quasiquote">
    <xsl:param name="ast"/>
    <xsl:variable name="result">
      <xsl:choose>
        <xsl:when test="fn:is-pair($ast)">
          <xsl:choose>
              <xsl:when test="let $fst := $ast/lvalue/malval[1]
                                  return $fst/@kind = 'symbol' and
                                       $fst/@value = 'unquote'">
              <xsl:sequence select="$ast/lvalue/malval[2]"/>
            </xsl:when>
            <xsl:when test="let $fst := $ast/lvalue/malval[1]
                                return fn:is-pair($fst) and
                                (let $fstfst := $fst/lvalue/malval[1]
                                    return $fstfst/@kind = 'symbol' and
                                       $fstfst/@value = 'splice-unquote')">
              <malval kind="list">
                <lvalue>
                  <malval kind="symbol" value="concat"/>
                  <xsl:sequence select="$ast/lvalue/malval[1]/lvalue/malval[2]"/>
                  <xsl:variable name="rest" select="$ast/lvalue/malval[position() &gt; 1]"/>
                  <xsl:variable name="rest-">
                    <malval kind="list">
                      <lvalue>
                        <xsl:sequence select="$rest"/>
                      </lvalue>
                    </malval>
                  </xsl:variable>
                  <xsl:call-template name="quasiquote">
                    <xsl:with-param name="ast" select="$rest-"/>
                  </xsl:call-template>
                </lvalue>
              </malval>
            </xsl:when>
            <xsl:otherwise>
              <malval kind="list">
                <lvalue>
                  <malval kind="symbol" value="cons"/>
                  <xsl:variable name="first" select="$ast/lvalue/malval[1]"/>
                  <xsl:variable name="rest" select="$ast/lvalue/malval[position() &gt; 1]"/>
                  <xsl:variable name="rest-">
                    <malval kind="list">
                      <lvalue>
                        <xsl:sequence select="$rest"/>
                      </lvalue>
                    </malval>
                  </xsl:variable>
                  <xsl:call-template name="quasiquote">
                    <xsl:with-param name="ast" select="$first"/>
                  </xsl:call-template>
                  <xsl:call-template name="quasiquote">
                    <xsl:with-param name="ast" select="$rest-/malval"/>
                  </xsl:call-template>
                </lvalue>
              </malval>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:when>
        <xsl:otherwise>
          <malval kind="list">
            <lvalue>
              <malval kind="symbol" value="quote"/>
              <xsl:sequence select="$ast"/>
            </lvalue>
          </malval>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:sequence select="$result"/>
  </xsl:template>
  <xsl:template name="macroexpand">
    <xsl:param name="ast"/>
    <xsl:param name="env"/>
    <xsl:param name="encode-env"/>
    <xsl:choose>
      <xsl:when test="fn:is-macro-call($ast, $env)">
        <xsl:variable name="fn" select="env:get($env, $ast/lvalue/malval[1]/@value)"/>
        <xsl:variable name="args">
          <value>
            <malval kind="list">
              <lvalue>
                <xsl:sequence select="$ast/lvalue/malval[position() &gt; 1]"/>
              </lvalue>
            </malval>
          </value>
        </xsl:variable>
        <xsl:variable name="new">
          <xsl:call-template name="uapply">
            <xsl:with-param name="func" select="$fn"/>
            <xsl:with-param name="args" select="$args"/>
            <xsl:with-param name="env" select="$env"/>
          </xsl:call-template>
        </xsl:variable>
        <xsl:call-template name="macroexpand">
          <xsl:with-param name="ast" select="$new/value/malval"/>
          <xsl:with-param name="env" select="$env"/>
          <xsl:with-param name="encode-env" select="$encode-env"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <value>
          <xsl:sequence select="$ast"/>
        </value>
        <xsl:sequence select="atoms[1]"/>
        <xsl:if test="$encode-env">
          <env data="{$env =&gt; env:serialise()}"/>
        </xsl:if>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <xsl:template name="EVAL">
    <xsl:param name="env"/>
    <xsl:param name="encode-env" select="true()"/>
    <xsl:variable name="atoms" select="atoms[1]"/>
    <xsl:variable name="data">
      <xsl:choose>
        <xsl:when test="value/malval/@kind = 'list'">
          <xsl:choose>
            <xsl:when test="count(value/malval/lvalue/malval) = 0">
              <xsl:sequence select="."/>
              <xsl:if test="$encode-env">
                <env data="{env:serialise($env)}"/>
              </xsl:if>
              <xsl:sequence select="$atoms"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:variable name="mexp">
                <xsl:call-template name="macroexpand">
                  <xsl:with-param name="ast" select="value/malval"/>
                  <xsl:with-param name="env" select="$env"/>
                  <xsl:with-param name="encode-env" select="$encode-env"/>
                </xsl:call-template>
              </xsl:variable>
              <xsl:for-each select="$mexp">
                <xsl:choose>
                  <xsl:when test="value/malval/@kind != 'list'">
                    <xsl:variable name="ctx">
                      <xsl:sequence select="value"/>
                    </xsl:variable>
                    <xsl:for-each select="$ctx">
                      <xsl:call-template name="eval_ast">
                        <xsl:with-param name="atoms" select="$atoms"/>
                        <xsl:with-param name="env" select="$env"/>
                      </xsl:call-template>
                      <xsl:if test="$encode-env">
                        <env data="{env:serialise($env)}"/>
                      </xsl:if>
                      <!-- <xsl:sequence select="$atoms"/> -->
                    </xsl:for-each>
                  </xsl:when>
                  <xsl:when test="let $fn := value/malval/lvalue/malval[1]
                                      return $fn/@kind = 'symbol' and
                                           $fn/@value = 'def!'">
                    <xsl:variable name="name">
                      <xsl:value-of select="value/malval/lvalue/malval[2]/@value"/>
                    </xsl:variable>
                    <xsl:variable name="xvalue">
                      <value>
                        <xsl:sequence select="value/malval/lvalue/malval[3]"/>
                      </value>
                      <xsl:sequence select="$atoms"/>
                    </xsl:variable>
                    <xsl:variable name="value">
                      <xsl:for-each select="$xvalue">
                        <xsl:call-template name="EVAL">
                          <xsl:with-param name="env" select="$env"/>
                          <xsl:with-param name="encode-env" select="false()"/>
                        </xsl:call-template>
                      </xsl:for-each>
                    </xsl:variable>
                    <xsl:sequence select="$value/data/value"/>
                    <xsl:if test="$encode-env">
                      <env data="{env:serialise(env:set($env, $name, $value/data/value/malval))}"/>
                    </xsl:if>
                    <xsl:sequence select="$value/atoms[1]"/>
                  </xsl:when>
                  <xsl:when test="let $fn := value/malval/lvalue/malval[1]
                                      return $fn/@kind = 'symbol' and
                                           $fn/@value = 'defmacro!'">
                    <xsl:variable name="name">
                      <xsl:value-of select="value/malval/lvalue/malval[2]/@value"/>
                    </xsl:variable>
                    <xsl:variable name="xvalue">
                      <value>
                        <xsl:sequence select="value/malval/lvalue/malval[3]"/>
                      </value>
                      <xsl:sequence select="$atoms"/>
                    </xsl:variable>
                    <xsl:variable name="value">
                      <xsl:for-each select="$xvalue">
                        <xsl:call-template name="EVAL">
                          <xsl:with-param name="env" select="$env"/>
                          <xsl:with-param name="encode-env" select="false()"/>
                        </xsl:call-template>
                      </xsl:for-each>
                    </xsl:variable>
                    <xsl:variable name="resv">
                      <value>
                        <malval kind="{$value/data/value/malval/@kind}" value="{$value/data/value/malval/@value}">
                          <xsl:sequence select="$value/data/value/malval/*[name() != 'is_macro']"/>
                          <is_macro>true</is_macro>
                        </malval>
                      </value>
                    </xsl:variable>
                    <xsl:sequence select="$resv"/>
                    <xsl:if test="$encode-env">
                      <env data="{env:serialise(env:set($env, $name, $resv/value/malval))}"/>
                    </xsl:if>
                    <xsl:sequence select="$resv/atoms[1]"/>
                  </xsl:when>
                  <xsl:when test="let $fn := value/malval/lvalue/malval[1]
                                      return $fn/@kind = 'symbol' and
                                           $fn/@value = 'let*'">
                    <xsl:variable name="xvalue">
                      <value>
                        <xsl:sequence select="value/malval/lvalue/malval[3]"/>
                      </value>
                      <xsl:sequence select="$atoms"/>
                    </xsl:variable>
                    <xsl:iterate select="fn:group_consec(value/malval/lvalue/malval[2]/lvalue/malval)">
                      <xsl:param name="new_env" select="env:close($env)"/>
                      <xsl:param name="new_atoms" select="$atoms"/>
                      <xsl:on-completion>
                        <xsl:variable name="xvalue">
                          <xsl:sequence select="$xvalue/value"/>
                          <xsl:sequence select="$new_atoms"/>
                        </xsl:variable>
                        <xsl:variable name="value">
                          <xsl:for-each select="$xvalue">
                            <xsl:call-template name="EVAL">
                              <xsl:with-param name="env" select="$new_env"/>
                              <xsl:with-param name="encode-env" select="$encode-env"/>
                            </xsl:call-template>
                          </xsl:for-each>
                        </xsl:variable>
                        <xsl:sequence select="$value/data/value"/>
                        <xsl:if test="$encode-env">
                          <env data="{env:serialise(env:swap-replEnv($env, env:deserialise($value/env/@data) =&gt; env:replEnv()))}"/>
                        </xsl:if>
                        <xsl:sequence select="$value/atoms[1]"/>
                      </xsl:on-completion>
                      <xsl:variable name="name">
                        <xsl:value-of select="node()[name() = 'first']/malval/@value"/>
                      </xsl:variable>
                      <xsl:variable name="xvalue">
                        <value>
                          <xsl:sequence select="node()[name() = 'second']/malval"/>
                        </value>
                        <xsl:sequence select="$new_atoms"/>
                      </xsl:variable>
                      <xsl:variable name="value">
                        <xsl:for-each select="$xvalue">
                          <xsl:call-template name="EVAL">
                            <xsl:with-param name="env" select="$new_env"/>
                            <xsl:with-param name="encode-env" select="false()"/>
                          </xsl:call-template>
                        </xsl:for-each>
                      </xsl:variable>
                      <xsl:next-iteration>
                        <xsl:with-param name="new_env" select="env:set($new_env, $name, $value/data/value/malval)"/>
                        <xsl:with-param name="new_atoms" select="$value/atoms[1]"/>
                      </xsl:next-iteration>
                    </xsl:iterate>
                  </xsl:when>
                  <xsl:when test="let $fn := value/malval/lvalue/malval[1]
                                      return $fn/@kind = 'symbol' and
                                           $fn/@value = 'do'">
                    <xsl:iterate select="value/malval/lvalue/malval[position() &gt; 1]">
                      <xsl:param name="new_env" select="$env"/>
                      <xsl:param name="atoms" select="$atoms"/>
                      <xsl:param name="previous_res" select="()"/>
                      <xsl:on-completion>
                        <xsl:sequence select="$previous_res"/>
                        <xsl:if test="$encode-env">
                          <env data="{env:serialise($new_env)}"/>
                        </xsl:if>
                        <xsl:sequence select="$atoms"/>
                      </xsl:on-completion>
                      <xsl:variable name="xvalue">
                        <value>
                          <xsl:sequence select="."/>
                        </value>
                        <xsl:sequence select="$atoms"/>
                      </xsl:variable>
                      <xsl:variable name="value">
                        <xsl:for-each select="$xvalue">
                          <xsl:call-template name="EVAL">
                            <xsl:with-param name="env" select="$new_env"/>
                          </xsl:call-template>
                        </xsl:for-each>
                      </xsl:variable>
                      <xsl:next-iteration>
                        <xsl:with-param name="new_env" select="env:deserialise($value/env/@data)"/>
                        <xsl:with-param name="previous_res" select="$value/data/value"/>
                        <xsl:with-param name="atoms" select="$value/atoms[1]"/>
                      </xsl:next-iteration>
                    </xsl:iterate>
                  </xsl:when>
                  <xsl:when test="let $fn := value/malval/lvalue/malval[1]
                                      return $fn/@kind = 'symbol' and
                                           $fn/@value = 'if'">
                    <xsl:variable name="cond">
                      <xsl:for-each select="value/malval/lvalue/malval[2]">
                        <xsl:variable name="context">
                          <value>
                            <xsl:sequence select="."/>
                          </value>
                          <xsl:sequence select="$atoms"/>
                        </xsl:variable>
                        <xsl:for-each select="$context">
                          <xsl:call-template name="EVAL">
                            <xsl:with-param name="env" select="$env"/>
                            <xsl:with-param name="encode-env" select="false()"/>
                          </xsl:call-template>
                        </xsl:for-each>
                      </xsl:for-each>
                    </xsl:variable>
                    <xsl:variable name="ptrue">
                      <xsl:for-each select="value/malval/lvalue/malval[3]">
                        <value>
                          <xsl:sequence select="."/>
                        </value>
                        <xsl:sequence select="$cond/atoms[1]"/>
                      </xsl:for-each>
                    </xsl:variable>
                    <xsl:variable name="pfalse">
                      <xsl:for-each select="value/malval/lvalue/malval[4]">
                        <value>
                          <xsl:sequence select="."/>
                        </value>
                        <xsl:sequence select="$cond/atoms[1]"/>
                      </xsl:for-each>
                    </xsl:variable>
                    <xsl:variable name="xfalse">
                      <xsl:choose>
                        <xsl:when test="empty($pfalse/value)">
                          <value>
                            <malval kind="nil"/>
                          </value>
                          <xsl:sequence select="$cond/atoms[1]"/>
                        </xsl:when>
                        <xsl:otherwise>
                          <xsl:sequence select="$pfalse/value"/>
                          <xsl:sequence select="$pfalse/atoms[1]"/>
                        </xsl:otherwise>
                      </xsl:choose>
                    </xsl:variable>
                    <xsl:variable name="res">
                      <xsl:choose>
                          <xsl:when test="let $kind := $cond/data/value/malval/@kind
                                              return $kind = 'nil' or $kind
                                               = 'false'">
                          <xsl:for-each select="$xfalse">
                            <xsl:call-template name="EVAL">
                              <xsl:with-param name="env" select="$env"/>
                              <xsl:with-param name="encode-env" select="$encode-env"/>
                            </xsl:call-template>
                          </xsl:for-each>
                        </xsl:when>
                        <xsl:otherwise>
                          <xsl:for-each select="$ptrue">
                            <xsl:call-template name="EVAL">
                              <xsl:with-param name="env" select="$env"/>
                              <xsl:with-param name="encode-env" select="$encode-env"/>
                            </xsl:call-template>
                          </xsl:for-each>
                        </xsl:otherwise>
                      </xsl:choose>
                    </xsl:variable>
                    <xsl:sequence select="$res/data/value"/>
                    <xsl:if test="$encode-env">
                      <env data="{env:serialise($env)}"/>
                    </xsl:if>
                    <xsl:sequence select="$res/atoms[1]"/>
                  </xsl:when>
                  <xsl:when test="let $fn := value/malval/lvalue/malval[1]
                                      return $fn/@kind = 'symbol' and
                                           $fn/@value = 'fn*'">
                    <value>
                      <malval kind="userfunction">
                        <is_macro>false</is_macro>
                        <binds>
                          <xsl:sequence select="value/malval/lvalue/malval[2]/lvalue/malval"/>
                        </binds>
                        <body>
                          <xsl:sequence select="value/malval/lvalue/malval[3]"/>
                        </body>
                        <env data="{env:serialise(env:noReplEnv($env))}"/>
                        <!-- capture current env -->
                      </malval>
                    </value>
                    <xsl:if test="$encode-env">
                      <env data="{env:serialise($env)}"/>
                    </xsl:if>
                    <xsl:sequence select="$atoms"/>
                  </xsl:when>
                  <xsl:when test="let $fn := value/malval/lvalue/malval[1]
                                      return $fn/@kind = 'symbol' and
                                           $fn/@value = 'quote'">
                    <value>
                      <xsl:sequence select="value/malval/lvalue/malval[2]"/>
                    </value>
                    <xsl:if test="$encode-env">
                      <env data="{env:serialise($env)}"/>
                    </xsl:if>
                    <xsl:sequence select="$atoms"/>
                  </xsl:when>
                  <xsl:when test="let $fn := value/malval/lvalue/malval[1]
                                      return $fn/@kind = 'symbol' and
                                           $fn/@value = 'quasiquote'">
                    <xsl:variable name="exp">
                      <value>
                        <xsl:call-template name="quasiquote">
                          <xsl:with-param name="ast" select="value/malval/lvalue/malval[2]"/>
                        </xsl:call-template>
                      </value>
                      <xsl:sequence select="$atoms"/>
                    </xsl:variable>
                    <xsl:variable name="res">
                      <xsl:for-each select="$exp">
                        <xsl:call-template name="EVAL">
                          <xsl:with-param name="env" select="$env"/>
                          <xsl:with-param name="encode-env" select="$encode-env"/>
                        </xsl:call-template>
                      </xsl:for-each>
                    </xsl:variable>
                    <xsl:sequence select="$res/data/value"/>
                    <xsl:if test="$encode-env">
                      <xsl:sequence select="$res/env"/>
                    </xsl:if>
                    <xsl:sequence select="$res/atoms[1]"/>
                  </xsl:when>
                  <xsl:when test="let $fn := value/malval/lvalue/malval[1]
                                      return $fn/@kind = 'symbol' and
                                           $fn/@value = 'macroexpand'">
                    <xsl:variable name="exp">
                      <xsl:call-template name="macroexpand">
                        <xsl:with-param name="ast" select="value/malval/lvalue/malval[2]"/>
                        <xsl:with-param name="env" select="$env"/>
                        <xsl:with-param name="encode-env" select="false()"/>
                      </xsl:call-template>
                      <xsl:sequence select="$atoms"/>
                    </xsl:variable>
                    <xsl:sequence select="$exp/value"/>
                    <xsl:if test="$encode-env">
                      <env data="{env:serialise($env)}"/>
                    </xsl:if>
                    <xsl:sequence select="$atoms"/>
                  </xsl:when>
                  <xsl:when test="let $fn := value/malval/lvalue/malval[1]
                                      return $fn/@kind = 'symbol' and
                                           $fn/@value = 'try*'">
                    <xsl:variable name="tryv">
                      <xsl:try>
                        <xsl:variable name="xvalue">
                          <value>
                            <xsl:sequence select="value/malval/lvalue/malval[2]"/>
                          </value>
                          <xsl:sequence select="$atoms"/>
                        </xsl:variable>
                        <xsl:variable name="value">
                          <xsl:for-each select="$xvalue">
                            <xsl:call-template name="EVAL">
                              <xsl:with-param name="env" select="$env"/>
                              <xsl:with-param name="encode-env" select="$encode-env"/>
                            </xsl:call-template>
                          </xsl:for-each>
                        </xsl:variable>
                        <xsl:sequence select="$value/data/value"/>
                        <xsl:if test="$encode-env">
                          <xsl:sequence select="$value/env"/>
                        </xsl:if>
                        <xsl:sequence select="$value/atoms[1]"/>
                        <xsl:catch errors="*">
                          <xsl:variable name="catchv-name" select="value/malval/lvalue/malval[3]/lvalue/malval[2]/@value"/>
                          <xsl:variable name="catchv">
                            <value>
                              <xsl:sequence select="value/malval/lvalue/malval[3]/lvalue/malval[3]"/>
                            </value>
                          </xsl:variable>
                          <xsl:if test="empty($catchv/value/malval)">
                            <xsl:value-of select="error($err:code, $err:description, $err:value)"/>
                          </xsl:if>
                          <xsl:variable name="newenv" select="env:close($env) =&gt; env:set($catchv-name, $err:value)"/>
                          <xsl:variable name="value">
                            <xsl:for-each select="$catchv">
                              <xsl:call-template name="EVAL">
                                <xsl:with-param name="env" select="$newenv"/>
                                <xsl:with-param name="encode-env" select="$encode-env"/>
                              </xsl:call-template>
                            </xsl:for-each>
                          </xsl:variable>
                          <xsl:sequence select="$value/data/value"/>
                          <xsl:if test="$encode-env">
                            <env data="{$env =&gt; env:serialise()}"/>
                          </xsl:if>
                          <xsl:sequence select="$value/atoms[1]"/>
                        </xsl:catch>
                      </xsl:try>
                    </xsl:variable>
                    <xsl:sequence select="$tryv"/>
                  </xsl:when>
                  <xsl:otherwise>
                    <xsl:variable name="new_list">
                      <xsl:call-template name="eval_ast">
                        <xsl:with-param name="atoms" select="$atoms"/>
                        <xsl:with-param name="env" select="$env"/>
                      </xsl:call-template>
                    </xsl:variable>
                    <xsl:variable name="func">
                      <xsl:for-each select="$new_list">
                        <xsl:sequence select="value/malval/lvalue/malval[1]"/>
                      </xsl:for-each>
                    </xsl:variable>
                    <xsl:variable name="args">
                      <xsl:for-each select="$new_list">
                        <value>
                          <malval kind="list">
                            <lvalue>
                              <xsl:for-each select="value/malval/lvalue/node()[position() != 1]">
                                <xsl:sequence select="."/>
                              </xsl:for-each>
                            </lvalue>
                          </malval>
                        </value>
                        <xsl:sequence select="$new_list/atoms"/>
                      </xsl:for-each>
                    </xsl:variable>
                    <xsl:variable name="resultv">
                      <xsl:choose>
                        <xsl:when test="$func/malval/@kind = 'userfunction'">
                          <xsl:call-template name="uapply">
                            <xsl:with-param name="env" select="$env"/>
                            <xsl:with-param name="func" select="$func"/>
                            <xsl:with-param name="args" select="$args"/>
                          </xsl:call-template>
                        </xsl:when>
                        <xsl:otherwise>
                          <xsl:choose>
                            <xsl:when test="$func/malval/@name = 'env??'">
                              <!-- needs access to env -->
                              <xsl:variable name="nev" select="env:dump($env)"/>
                              <xsl:variable name="value">
                                <malval kind="string" value="{$env =&gt; serialize(map{'method':'json'})}"/>
                              </xsl:variable>
                              <value>
                                <xsl:sequence select="$value"/>
                              </value>
                              <xsl:if test="$encode-env">
                                <env data="{env:serialise($env)}"/>
                              </xsl:if>
                              <xsl:sequence select="$value/atoms[1]"/>
                            </xsl:when>
                            <xsl:when test="$func/malval/@name = 'eval'">
                              <!-- needs access to env -->
                              <xsl:variable name="venv" select="env:replEnv($env)"/>
                              <xsl:variable name="form">
                                <value>
                                  <xsl:sequence select="$args/value/malval/lvalue/malval[1]"/>
                                </value>
                                <xsl:sequence select="$atoms"/>
                              </xsl:variable>
                              <xsl:variable name="value">
                                <xsl:for-each select="$form">
                                  <xsl:call-template name="EVAL">
                                    <xsl:with-param name="env" select="$venv"/>
                                    <xsl:with-param name="encode-env" select="$encode-env"/>
                                  </xsl:call-template>
                                </xsl:for-each>
                              </xsl:variable>
                              <xsl:sequence select="$value/data/value"/>
                              <xsl:if test="$encode-env">
                                <env data="{env:serialise(env:swap-replEnv($env, env:deserialise($value/env/@data)))}"/>
                              </xsl:if>
                              <xsl:sequence select="$value/atoms[1]"/>
                            </xsl:when>
                            <xsl:when test="$func/malval/@name = 'atom'">
                              <!-- needs access to atoms -->
                              <xsl:variable name="atom-ident" select="count($atoms/atom)"/>
                              <value>
                                <malval kind="atom" value="{$atom-ident}"/>
                              </value>
                              <atoms>
                                <xsl:for-each select="$atoms/atom">
                                  <xsl:sequence select="."/>
                                </xsl:for-each>
                                <atom identity="{$atom-ident}">
                                  <xsl:sequence select="$args/value/malval/lvalue/malval[1]"/>
                                </atom>
                              </atoms>
                            </xsl:when>
                            <xsl:when test="$func/malval/@name = 'deref'">
                              <!-- needs access to atoms -->
                              <value>
                                <xsl:sequence select="$atoms/atom[@identity = $args/value/malval/lvalue/malval[1]/@value]/malval"/>
                              </value>
                              <xsl:sequence select="$atoms"/>
                            </xsl:when>
                            <xsl:when test="$func/malval/@name = 'reset!'">
                              <!-- needs access to atoms -->
                              <xsl:variable name="atom-ident" select="$args/value/malval/lvalue/malval[1]/@value"/>
                              <xsl:variable name="newv" select="$args/value/malval/lvalue/malval[2]"/>
                              <value>
                                <xsl:sequence select="$newv"/>
                              </value>
                              <atoms>
                                <xsl:for-each select="$atoms/atom[@identity != $atom-ident]">
                                  <xsl:sequence select="."/>
                                </xsl:for-each>
                                <atom identity="{$atom-ident}">
                                  <xsl:sequence select="$newv"/>
                                </atom>
                              </atoms>
                            </xsl:when>
                            <xsl:when test="$func/malval/@name = 'swap!'">
                              <!-- needs access to atoms -->
                              <xsl:variable name="atom-ident" select="$args/value/malval/lvalue/malval[1]/@value"/>
                              <xsl:variable name="atom-value" select="$atoms/atom[@identity = $atom-ident]/malval"/>
                              <xsl:variable name="fn">
                                <xsl:sequence select="$args/value/malval/lvalue/malval[2]"/>
                              </xsl:variable>
                              <xsl:variable name="cargs">
                                <value>
                                  <malval kind="list">
                                    <lvalue>
                                      <xsl:sequence select="$atom-value"/>
                                      <xsl:sequence select="$args/value/malval/lvalue/malval[position() &gt; 2]"/>
                                    </lvalue>
                                  </malval>
                                </value>
                              </xsl:variable>
                              <xsl:variable name="newv">
                                <xsl:call-template name="call-function">
                                  <xsl:with-param name="func" select="$fn"/>
                                  <xsl:with-param name="args" select="$cargs"/>
                                  <xsl:with-param name="env" select="$env"/>
                                </xsl:call-template>
                              </xsl:variable>
                              <xsl:sequence select="$newv/value"/>
                              <atoms>
                                <xsl:for-each select="$newv/atoms[1]/atom[@identity != $atom-ident]">
                                  <xsl:sequence select="."/>
                                </xsl:for-each>
                                <atom identity="{$atom-ident}">
                                  <xsl:sequence select="$newv/value/malval"/>
                                </atom>
                              </atoms>
                              <xsl:sequence select="$newv/env"/>
                            </xsl:when>
                            <xsl:when test="$func/malval/@name = 'apply'">
                              <!-- needs access to env -->
                              <!-- (apply F A... T) -> (F A... T...) -->
                              <xsl:variable name="fun">
                                <xsl:sequence select="$args/value/malval/lvalue/malval[1]"/>
                              </xsl:variable>
                              <xsl:variable name="args">
                                <value>
                                  <malval kind="list">
                                    <lvalue>
                                      <xsl:variable name="argc" select="count($args/value/malval/lvalue/malval)"/>
                                      <xsl:sequence select="$args/value/malval/lvalue/malval[position() gt 1 and position() lt $argc]"/>
                                      <xsl:sequence select="$args/value/malval/lvalue/malval[$argc]/lvalue/malval"/>
                                    </lvalue>
                                  </malval>
                                </value>
                              </xsl:variable>
                              <xsl:variable name="res">
                                <xsl:call-template name="call-function">
                                  <xsl:with-param name="func" select="$fun"/>
                                  <xsl:with-param name="args" select="$args"/>
                                  <xsl:with-param name="env" select="$env"/>
                                </xsl:call-template>
                              </xsl:variable>
                              <xsl:sequence select="$res/value"/>
                              <xsl:sequence select="$res/env"/>
                              <xsl:sequence select="$res/atoms[1]"/>
                            </xsl:when>
                            <xsl:when test="$func/malval/@name = 'map'">
                              <!-- needs access to env -->
                              <!-- (map F T) -> (list (F Tx)...) -->
                              <xsl:variable name="func">
                                <xsl:sequence select="$args/value/malval/lvalue/malval[1]"/>
                              </xsl:variable>
                              <xsl:iterate select="$args/value/malval/lvalue/malval[2]/lvalue/malval">
                                <xsl:param name="xenv" select="$env"/>
                                <xsl:param name="atoms" select="$atoms"/>
                                <xsl:param name="value" select="()"/>
                                <xsl:on-completion>
                                  <value>
                                    <malval kind="list">
                                      <lvalue>
                                        <xsl:sequence select="$value"/>
                                      </lvalue>
                                    </malval>
                                  </value>
                                  <xsl:if test="$encode-env">
                                    <env data="{$env =&gt; env:serialise()}"/>
                                  </xsl:if>
                                  <xsl:sequence select="$atoms"/>
                                </xsl:on-completion>
                                <xsl:variable name="args">
                                  <value>
                                    <malval kind="list">
                                      <lvalue>
                                        <xsl:sequence select="."/>
                                      </lvalue>
                                    </malval>
                                  </value>
                                </xsl:variable>
                                <xsl:variable name="res">
                                  <xsl:call-template name="call-function">
                                    <xsl:with-param name="func" select="$func"/>
                                    <xsl:with-param name="args" select="$args"/>
                                    <xsl:with-param name="env" select="$xenv"/>
                                  </xsl:call-template>
                                </xsl:variable>
                                <xsl:next-iteration>
                                  <xsl:with-param name="xenv" select="env:deserialise($res/env/@data)"/>
                                  <xsl:with-param name="atoms" select="$res/atoms[1]"/>
                                  <xsl:with-param name="value" select="$value, $res/value/malval"/>
                                </xsl:next-iteration>
                              </xsl:iterate>
                            </xsl:when>
                            <xsl:otherwise>
                              <xsl:variable name="ctx">
                                <xsl:sequence select="$atoms"/>
                              </xsl:variable>
                              <xsl:for-each select="$ctx">
                                <xsl:call-template name="core-apply">
                                  <xsl:with-param name="func" select="$func"/>
                                  <xsl:with-param name="args" select="$args"/>
                                </xsl:call-template>
                              </xsl:for-each>
                              <xsl:sequence select="$atoms"/>
                            </xsl:otherwise>
                          </xsl:choose>
                        </xsl:otherwise>
                      </xsl:choose>
                    </xsl:variable>
                    <xsl:for-each select="$resultv">
                      <xsl:choose>
                        <xsl:when test="empty(env)">
                          <xsl:if test="$encode-env">
                            <env data="{env:serialise($env)}"/>
                          </xsl:if>
                        </xsl:when>
                        <xsl:otherwise>
                          <xsl:if test="$encode-env">
                            <xsl:sequence select="env"/>
                          </xsl:if>
                        </xsl:otherwise>
                      </xsl:choose>
                      <xsl:sequence select="atoms[1]"/>
                      <xsl:sequence select="value"/>
                    </xsl:for-each>
                  </xsl:otherwise>
                </xsl:choose>
              </xsl:for-each>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:when>
        <xsl:otherwise>
          <xsl:call-template name="eval_ast">
            <xsl:with-param name="atoms" select="$atoms"/>
            <xsl:with-param name="env" select="$env"/>
          </xsl:call-template>
          <xsl:if test="$encode-env">
            <env data="{env:serialise($env)}"/>
          </xsl:if>
          <!-- <xsl:sequence select="$atoms"/> -->
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <data>
      <xsl:sequence select="$data/value"/>
    </data>
    <xsl:if test="$encode-env">
      <env data="{$data/env/@data}"/>
    </xsl:if>
    <xsl:sequence select="$data/atoms[1]"/>
  </xsl:template>
  <xsl:template name="READ">
    <xsl:variable name="context">
      <str>
        <xsl:copy-of select="stdin/text()"/>
      </str>
    </xsl:variable>
    <xsl:variable name="form">
      <xsl:sequence select="state/atoms[1]"/>
      <xsl:for-each select="$context">
        <xsl:call-template name="malreader-read_str"/>
      </xsl:for-each>
    </xsl:variable>
    <xsl:for-each select="$form">
      <xsl:if test="error">
        <xsl:value-of select="error(QName('MAL', 'Error'), string(error))"/>
      </xsl:if>
      <xsl:sequence select="."/>
    </xsl:for-each>
  </xsl:template>
  <xsl:function name="fn:group_consec">
    <xsl:param name="nodes"/>
    <xsl:variable name="groups">
      <xsl:for-each-group select="$nodes" group-by="position() mod 2">
        <xsl:choose>
          <xsl:when test="position() = 1">
            <first>
              <xsl:sequence select="current-group()"/>
            </first>
          </xsl:when>
          <xsl:otherwise>
            <second>
              <xsl:sequence select="current-group()"/>
            </second>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:for-each-group>
    </xsl:variable>
    <xsl:iterate select="1 to count($groups/first/*)">
      <element>
        <xsl:variable name="idx" select="number(.)"/>
        <first>
          <xsl:sequence select="$groups/first/node()[position() = $idx]"/>
        </first>
        <second>
          <xsl:sequence select="$groups/second/node()[position() = $idx]"/>
        </second>
      </element>
    </xsl:iterate>
  </xsl:function>
  <xsl:function name="fn:is-pair">
    <xsl:param name="list"/>
    <xsl:sequence select="($list/@kind = 'list' or $list/@kind = 'vector') and count($list/lvalue/malval) != 0"/>
  </xsl:function>
  <xsl:function name="fn:is-macro-call">
    <xsl:param name="ast"/>
    <xsl:param name="env"/>
    <xsl:variable name="res" select="$ast/@kind = 'list' and
                                     $ast/lvalue/malval[1]/@kind = 'symbol' and
                                     (let $fn := env:get-noerror($env, $ast/lvalue/malval[1]/@value)
                                        return not(empty($fn)) and
                                            $fn/malval/is_macro/text() = 'true')"/>
    <xsl:sequence select="$res"/>
  </xsl:function>
</xsl:stylesheet>
