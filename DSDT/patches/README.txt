This set of patches can be used in DSDT Editor or (preferably) MaciASL to apply
some common patches to your laptop for running OS X.  These patches are common
for Sandy Bridge or Ivy Bridge laptops.

Many of these patches came from work on the HP ProBook patches and/or work on my
own Intel DH67GD desktop.

Many of the battery patches were created over time, published as individual posts 
by me on tonymacx86.com, and collected here in this repository.


To add these patches to MaciASL as a repository:
- Run MaciASL
- choose Preferences from the MaciASL menu bar
- select Sources
- click the [+] button
- give it a name (eg. "Laptop Patches")
- type the following URL: http://raw.github.com/RehabMan/Laptop-DSDT-Patch/master

If you don't have internet access and wish to use a repository locally:
- download the .ZIP of the repository from github (Download ZIP button on right side)
- copy the resulting .ZIP to the laptop (via USB), for example, to your Documents folder
- unzip it in place
- now add the path to the 'sources' in MaciASL Preferences, in the case of this repo, copied to Documents, the URL/path would be file:///Users/YourUserName/Documents/Laptop-DSDT-Patch-master

After that you can use the repo just like a remote repo.


I recommend you use my version of MaciASL: 
https://github.com/RehabMan/OS-X-MaciASL-patchmatic


To apply a patch to your DSDT with MaciASL:
- run MaciASL
- if you already have a patched DSDT in /Extra, MaciASL will load it 
  (caption will say DSDT.AML)
- if you don't have a patched DSDT yet, caption will show "System DSDT"
- click Compile to verify you have an error free compile
  (only errors matter)
- if it has errors, you must fix them
- there are a few common error patches in the repo (first group)
- ok... back to how to apply a patch...
- click Patch (logical, right)
- select a patch from the repo that appears on the left
- MaciASL will show you a preview of the changes
- click Apply
- when you're done applying patches, click Close

To use your DSDT, you must save it to /Extra/dsdt.aml, format: ACPI Machine Language Binary

After saving it, reboot and test.  Boot with DSDT=null if there is an issue with
your DSDT that prevents you from booting.