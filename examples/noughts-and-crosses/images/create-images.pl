#!/usr/bin/perl

# Fetch a whole lot of Flickr URLs with an X (or O), and for each one
# capture the image, the credits, create a square crop, and write the
# details into Elm format for inclusion in an Elm source file.

capture("x", q{
https://www.flickr.com/photos/srta_lobo/22322265/
https://www.flickr.com/photos/miglesias/14114788851/
https://www.flickr.com/photos/adabo/28659408095/
https://www.flickr.com/photos/monceau/437040711/
https://www.flickr.com/photos/duncan/338679886/
https://www.flickr.com/photos/stomen/581113862/
https://www.flickr.com/photos/monceau/7895949896/
https://www.flickr.com/photos/el_ramon/49512289641/
https://www.flickr.com/photos/thoreaudown/4462010636/
https://www.flickr.com/photos/toofarnorth/1976928551/
https://www.flickr.com/photos/mag3737/8049594329/
https://www.flickr.com/photos/monceau/202058768/
https://www.flickr.com/photos/toofarnorth/2640277187/
https://www.flickr.com/photos/monceau/16861230960/
https://www.flickr.com/photos/duncan/2333776824/
https://www.flickr.com/photos/donut2d/7897244/
https://www.flickr.com/photos/monceau/30126568570/
https://www.flickr.com/photos/kiermacz/3461029517/
https://www.flickr.com/photos/monceau/182858181/
https://www.flickr.com/photos/mag3737/5645699930/
https://www.flickr.com/photos/monceau/377018022/
https://www.flickr.com/photos/wclaphotography/9113796592/
https://www.flickr.com/photos/monceau/158985299/
https://www.flickr.com/photos/mag3737/5987020486/
https://www.flickr.com/photos/monceau/367538757/
https://www.flickr.com/photos/mag3737/6138424021/
https://www.flickr.com/photos/monceau/3789759262/
https://www.flickr.com/photos/_boris/569118974/
https://www.flickr.com/photos/jeremygetscash/3090869594/
https://www.flickr.com/photos/mag3737/5987018910/
https://www.flickr.com/photos/jonroman/41206611494/
https://www.flickr.com/photos/monceau/23862771503/
https://www.flickr.com/photos/monceau/6480338013/
https://www.flickr.com/photos/mag3737/5987020702/
https://www.flickr.com/photos/monceau/312983060/
https://www.flickr.com/photos/monceau/158983348/
https://www.flickr.com/photos/_boris/2767435675/
https://www.flickr.com/photos/monceau/149476669/
https://www.flickr.com/photos/monceau/158983570/
https://www.flickr.com/photos/monceau/202049432/
https://www.flickr.com/photos/monceau/226345416/
https://www.flickr.com/photos/monceau/114302806/
https://www.flickr.com/photos/falcon19880125/3029180868/
https://www.flickr.com/photos/monceau/158983251/
https://www.flickr.com/photos/seemypicshere_pat/4125965432/
https://www.flickr.com/photos/monceau/3411096285/
https://www.flickr.com/photos/jmsmytaste/107479706/
https://www.flickr.com/photos/mag3737/5986496229/
https://www.flickr.com/photos/monceau/184813490/
https://www.flickr.com/photos/63465296@N07/8517164923/
https://www.flickr.com/photos/monceau/114302718/
https://www.flickr.com/photos/monceau/158985240/
https://www.flickr.com/photos/monceau/226345622/
https://www.flickr.com/photos/monceau/114303725/
https://www.flickr.com/photos/monceau/2443794738/
https://www.flickr.com/photos/monceau/158983196/
https://www.flickr.com/photos/monceau/487463283/
https://www.flickr.com/photos/monceau/487431868/
https://www.flickr.com/photos/monceau/528795547/
https://www.flickr.com/photos/monceau/6444139697/
https://www.flickr.com/photos/monceau/9339599532/
https://www.flickr.com/photos/thedepartment/29640955/
https://www.flickr.com/photos/zunkkis/3010236037/
https://www.flickr.com/photos/monceau/8967245205/
https://www.flickr.com/photos/monceau/215494056/
https://www.flickr.com/photos/monceau/2270030010/
https://www.flickr.com/photos/monceau/566538386/
https://www.flickr.com/photos/thomashawk/37620228412/i
https://www.flickr.com/photos/monceau/16765172345/
https://www.flickr.com/photos/cjsmithphotography/12432840033/
https://www.flickr.com/photos/duncan/537708260/
https://www.flickr.com/photos/monceau/26945844184/
https://www.flickr.com/photos/137221047@N04/44826306025/
https://www.flickr.com/photos/thomashawk/27809279749/
https://www.flickr.com/photos/mag3737/6142943062/
https://www.flickr.com/photos/monceau/244674768/
https://www.flickr.com/photos/monceau/3582875464/
https://www.flickr.com/photos/monceau/399308894/
https://www.flickr.com/photos/monceau/6312749935/
https://www.flickr.com/photos/theotherdan/484651465/
https://www.flickr.com/photos/monceau/5709126189/
https://www.flickr.com/photos/_boris/6002378384/
https://www.flickr.com/photos/monceau/23345492416/
https://www.flickr.com/photos/monceau/6242700214/
https://www.flickr.com/photos/mag3737/19823472461/
https://www.flickr.com/photos/mag3737/8707880575/
https://www.flickr.com/photos/bigbabymiguel/2459376341/
https://www.flickr.com/photos/2is3/2350657726/
https://www.flickr.com/photos/_boris/267804756/
https://www.flickr.com/photos/monceau/5820884646/
https://www.flickr.com/photos/monceau/7378902494/
https://www.flickr.com/photos/rom01/35202543195/
https://www.flickr.com/photos/craebby/22300421726/
https://www.flickr.com/photos/universaldilletant/25012938882/
https://www.flickr.com/photos/29997533@N03/48786079243/
https://www.flickr.com/photos/monceau/7645245776/
https://www.flickr.com/photos/stencilsrx/8161016839/
https://www.flickr.com/photos/mag3737/5792971358/
https://www.flickr.com/photos/19779889@N00/29959871538/
https://www.flickr.com/photos/emiliano-iko/28845305145/i
});

capture("o", q{
https://www.flickr.com/photos/duncan/36252614/
https://www.flickr.com/photos/smartfat/136061595/
});

print "Done!\n";

# For a mark (x or o) capture all the URLs given.
# Will die in the event of a problem.
sub capture {
    $mark = $_[0];
    $lines = $_[1];
    $count = 0;

    open URLS, '<', \$lines or die "Could not open lines\n";
    while (<URLS>) {
        chomp;
        $url = $_;
        if ($url eq "") {
            next;
        }

        print "\n\n-------------------------- Fetching $url\n";

        if (fetch($url, "index.html") != 0) {
            die "Could not fetch page URL $url\n";
        }
        if (processHtml() != 0) {
            die "Could not process HTML from URL $url\n";
        }

        print "Name = $name\n";
        print "URL = $imageUrl\n";

        # Fetch the image and create a square version

        if (fetch($imageUrl, "image.jpg") != 0) {
            die "Could not fetch image URL $imageUrl\n";
        }

        $output = "$mark/$count.jpg";
        $cmd = "gm convert image.jpg -thumbnail '600x600^' -gravity center -extent '600x600' +profile '*' $output";
        print "Converting: $cmd\n";
        if (system($cmd) != 0) {
            die "Could not process image from $imageUrl\n";
        }

        # Output the Elm
        open(ELM, ">>${mark}out.elm") or die "Could not open ${mark}out.elm\n";
        print ELM qq(
  , { src = "images/$output"
    , name = "$name"
    , link = "$url"
    });
        close(ELM);

        print "-------------------------- Done $output\n";

        # Tidy up
        `rm index.html`;
        `rm image.jpg`;

        ++$count;
    }
    close(URLS);
}

# Fetch a given URL into a given file.
# Returns 0 (success) or non-zero.
sub fetch {
    $url = $_[0];
    $out = $_[1];
    $result = system("wget -q -O $out $url");
    return $result;
}

# Process HTML in index.html.
# Sets global variables:
# $name    Name of creator
# $imageUrl   URL of the image
# Returns 0 (success or non-zero).
sub processHtml {
    $name = "";
    $imageUrl = "";

    open(OF, "index.html");

    while ($line = <OF>) {
        chomp $line;

        # Find the username
        if ($line =~ /<title>.*\|.*\|.*<\/title>/) {
            $line =~ s/[^|]*\|\s*//;
            $line =~ s/\s*\|.*//;
            $name = $line;
        }

        # Find the URL
        if ($line =~ /"url":.*_o\.jpg/) {
            $line =~ s/.*"([^"]*_o\.jpg).*/$1/;
            $line =~ s/\\//g;
            $imageUrl = "https:$line";
        }
    }

    if (length($name) >=2 && length($name) <= 50 &&
        length($imageUrl) >= 10 && length($imageUrl) <= 100) {
        # Good
        return 0;
    } else {
        # Bad
        return 1;
    }

    close(OF);
}
