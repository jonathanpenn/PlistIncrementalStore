Plist Incremental Store
=======================

This is a demonstration app to show off an experimental `NSIncrementalStore`
for Apple's [Core Data framework][cd]. I use it for the live coding part of my
`NSIncrementalStore` talks.

  [cd]: http://developer.apple.com/library/mac/documentation/cocoa/Conceptual/CoreData/cdProgrammingGuide.html

## What it does

The incremental store allows Core Data to write simple models (that is, models
without relationships) to Plist files in a specified directory. Not only does
it read and write the entities to plist files, but it watches the directory for
changes with `NSFileCoordinator/NSFilePresenter`. If it sees a changed or
removed file, then it notifies Core Data and anyone listening for changes (like
a fetched results controller) will be told of the new or removed object.

I originally built this as a research experiment to learn about Core Data and
see if it would be possible to sync simple models over a filesystem.
Theoretically this would work great with Dropbox (and I've done some testing
with this myself). I ended up not using it on the project I was working on
because I had more complex data model needs. Nonetheless, the learning
experience was a remarkable success and I'm sharing what I found here in this
repository.

I've commented throughout. Open an issue if something isn't clear. We can help
improve this together.

## How it works

The main part of the app is pretty boilerplate, just a simple Core Data Stack
used by a fetched results controller to feed a table view. The interesting part
starts in the `PlistIncrementalStore.m` file where all the magic takes place.
It constructs a `PlistStoreFileWatcher` that acts as the sole object
responsible for watching for changes and serializing access to the file system
to ensure atomicity.

When this store is active, it will be notified of changes by the
`PlistStoreFileWatcher` and tell Core Data what objects need to be handled
appropriately.

## So, does it work?

Yes! If you change files on disk or remove them, Core Data keeps up just fine.
If you put a file that has an invalid name or contents, then the store just
silently ignores them unless you have debug logging enabled.

If you tap the action button in the application, you'll see an option to create
many plist files programmatically on disk in a background queue so you can
watch Core Data churn through the file system notifications without breaking a
sweat. It works quite well, even on an older device.

## Contact

Questions? Ask!

Jonathan Penn

- http://cocoamanifest.net
- http://github.com/jonathanpenn
- http://twitter.com/jonathanpenn
- http://alpha.app.net/jonathanpenn
- jonathan@cocoamanifest.net

## License

Schedule is available under the MIT license. See the LICENSE file for more info.

