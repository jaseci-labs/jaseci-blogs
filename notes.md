This document should be used to understand how to write blogs.
* jac and python codeblocks that are inside of the div with the class "code-block" become runnable codeblocks with run button below the code.
ie <div class="code-block">
* To set python mode you add data-lang="python" to the field, ie <div class="code-block" data-lang="python">
* if "run-dot" is added to the class list, the codeblock will have an additional "graph" button to allow users to see the graph attached to root in the doc. (i.e. <div class="code-block run-dot">) That's based on the "jac dot [filename.jac] --to_screen" command. These should be added to example intended to have an OSP graph.
* You can look at the other .md files in the blog/post dir to see how they are used. 
* You can run `jac jac2py [filename.jac]` to get pure python versions of any jac code. Use that if you want python equivilant code to any jac. 
* Code examples that are intended to be run, should alwayys produce output and code examples intended to have a graph should always connect the graph to root. 
* If the code block is not intended to be runnable it should not be in the div. 
* Code examples should not be overly verbose, but highly effective in demonstrating what its supposed to. 
* You should always check any jac code examples created by runnint `jac run` or `jac dot ... --to_screen` to validate the output is as expected.
* You can learn the jac language by reading relevant .jac and .md files in /home/ninja/jaseci/jac/examples/reference/, these can also be run with the jac run command to see output for further understanding of the examples. 
* The tone of blog articles should be targeting professional developers.
* There shouldnt be over usage of bulleted lists, though ok when really suitable, tables, and mermaid diagrams should also be used in blogs
* Blog articles should only have up the 2 levels of headings including a single # or two ##, below that use blod for sub sections if needed


