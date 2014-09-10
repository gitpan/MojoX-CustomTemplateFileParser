use strict;
use Test::More;
use MojoX::CustomTemplateFileParser;

my $parser = MojoX::CustomTemplateFileParser->new(path => 'corpus/test-1.mojo', output => ['Html']);

my $expected = q{<div class="panel panel-default"><div class="panel-body"><pre>
    %= link_to &#39;MetaCPAN&#39;, &#39;http://www.metacpan.org/&#39;
</pre><pre>
    &lt;a href=&quot;http://www.metacpan.org/&quot;&gt;MetaCPAN&lt;/a&gt;
</pre><hr />    <a href="http://www.metacpan.org/">MetaCPAN</a></div></div><div class="panel panel-default"><div class="panel-body"><pre>
    %= text_field username =&gt; placeholder =&gt; &#39;first&#39;
</pre><pre>
    &lt;input name=&quot;username&quot; placeholder=&quot;first&quot; type=&quot;text&quot; /&gt;
</pre><hr />    <input name="username" placeholder="first" type="text" /></div></div><div class="panel panel-default"><div class="panel-body"><pre>
    %= text_field username =&gt; placeholder =&gt; &#39;name&#39;
</pre><pre>
    &lt;input name=&quot;username&quot; placeholder=&quot;name&quot; type=&quot;text&quot; /&gt;
</pre><hr />    <input name="username" placeholder="name" type="text" /></div></div>};

is $parser->to_html, $expected, 'Creates correct tests';


done_testing;
