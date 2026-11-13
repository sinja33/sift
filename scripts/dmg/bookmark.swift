// Prints macOS's own bookmark (file link) for a path to stdout.
// Finder on recent macOS only finds the install window's background through a bookmark made this way.
//   bookmark <path>
import Foundation

let url = URL(fileURLWithPath: CommandLine.arguments[1])
let data = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
FileHandle.standardOutput.write(data)
