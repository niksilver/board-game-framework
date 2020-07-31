#!/usr/bin/perl

# Fetch a whole lot of Flickr URLs with an X (or O), and for each one
# capture the image, the credits, create a square crop, and write the
# details into Elm format for inclusion in an Elm source file.

capture("x", q{
https://www.flickr.com/photos/srta_lobo/22322265/
https://www.flickr.com/photos/miglesias/14114788851/
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

        # Tidy the URL
        $url =~ s,/in/.*,/,;
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
