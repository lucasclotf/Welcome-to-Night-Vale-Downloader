import std.stdio;
import std.regex;
import std.range;
import std.datetime;
import std.file;
import std.algorithm;
import std.xml;
import std.conv;
import std.path;
import std.net.curl;
import core.thread;

// The URL of the RSS feed
auto rssUriStr = "http://feeds.feedburner.com/WelcomeToNightVale?format=xml";

// The directory to download the mp3 files into
string downloadDir;

// Returns a set of all MP3 URIs in the current RSS feed
int[string] getRssList() {
	// download rss
	auto rssStr = get(rssUriStr);

	// manually search for //media:content/@url
	int[string] res;
	auto xml = new DocumentParser(to!string(rssStr));
	xml.onStartTag["media:content"] = (ElementParser media) {
		res[media.tag().attr["url"]] = 1;
	};
	xml.parse();

	return res;
}

// Returns all files that are downloaded
string[] getLocalFiles(string downloadDir) {
	string[] local;
	foreach(entry; dirEntries(downloadDir, SpanMode.shallow)) {
		auto entryShort = split(entry.name, "\\")[$-1];
		local ~= [entryShort];
	}
	return local;
}

// Returns the filename of the mp3 uri
string uriToFilename(string uri) {
	return split(uri, "/")[$-1];
}

// Returns a list of uris that still need to be downloaded
// numLocal: number of files in rss that are also local
int[string] getUrisToDownload(string downloadDir, out int numLocal) {
	// get all files from rss
	auto allRssMp3s = getRssList();

	// get all local files
	auto allLocalMp3s = getLocalFiles(downloadDir);

	numLocal = 0;

	// if a file is already downloaded, remove it
	foreach(string mp3Uri; allRssMp3s.keys) {
		if(allLocalMp3s.canFind(uriToFilename(mp3Uri))) {
			allRssMp3s.remove(mp3Uri);
			numLocal++;
		}
	}

	return allRssMp3s;
}

// Downloads all missing mp3s
void sync(string downloadDir) {
	int localRssFiles = 0;
	auto urisToDownload = getUrisToDownload(downloadDir, localRssFiles);
	writefln("Local files: %s", localRssFiles);
	writefln("Files to download: %s", urisToDownload.keys.length);

	foreach(uri; urisToDownload.keys) {
		writefln("Downloading %s\n to %s", uri, buildPath(downloadDir, uriToFilename(uri)));
		stdout.flush();
		download(uri, buildPath(downloadDir, uriToFilename(uri)));
	}
}

// Main loop. Checks the rss feed every week if there is an expected episode
void main(string[] args) {
	if(args.length != 2) {
		stderr.writeln("Usage: wnv <downloaddir>");
		exit(1);
	}

	downloadDir = args[1];
	if(! exists(downloadDir) || ! isDir(downloadDir)) {
		stderr.writeln("Download directory does not exist");
		exit(1);
	}

	writeln("Starting");
	writeln();
	stdout.flush();
	while(true) {
		auto time = Clock.currTime().toSimpleString();
		writeln(time);
		writefln("Syncing %s", downloadDir);
		stdout.flush();

		sync(downloadDir);

		writeln("Sleeping");
		writeln();
		stdout.flush();
		Thread.getThis().sleep(dur!("hours")(6));
	}
}

