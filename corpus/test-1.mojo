
# Code here

==test example==
--t--
    %= link_to 'MetaCPAN', 'http://www.metacpan.org/'
--t--
--e--
    <a href="http://www.metacpan.org/">MetaCPAN</a>
--e--

==test loop(first name)==
--t--
    %= text_field username => placeholder => '[var]'
--t--
--e--
    <input name="username" placeholder="[var]" type="text" />
--e--

==no test==
--t--
    %= text_field username => placeholder => 'Not tested'
--t--
--e--
    <input name="username" placeholder="Not tested" type="text" />
--e--

==test==
--t--

--t--

--e--

--e--
