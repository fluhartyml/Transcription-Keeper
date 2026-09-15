//
//  BuildStamp.swift
//  Transcription Keeper
//
//  ⚠️ THE VALUES BELOW ARE REWRITTEN BY `Scripts/stamp-build.sh`. Do not hand-edit them.
//
//  Michael, 2026-09-08: "the about doesnt show the new build convention." The build
//  NUMBER was already honest — the post-commit hook writes the git commit count into
//  CURRENT_PROJECT_VERSION — but the About sheet showed only version and build, and the
//  stamp script had been saying so on every single run: "[no BuildStamp.swift — in-app
//  display not wired]". Twelve builds went to his phone with that notice in the output.
//
//  The standard is version · build number · short SHA · build time, and it exists so the
//  answer can be read OUT LOUD off the device by someone who cannot see Xcode. A number
//  that is correct inside the binary and invisible on the screen solves nothing: the day
//  this rule cost was a day of four devices that could not tell each other apart.
//
//  Full text: Workshop/BUILD-NUMBER-STANDARD.md

import Foundation

enum BuildStamp {
    /// Short SHA of HEAD when this build was stamped. A "+" suffix means the working tree
    /// had uncommitted changes, so the binary is that commit PLUS something unrecorded.
    static let commit = "e0cdd05+"

    /// Branch HEAD was on when this build was stamped.
    static let branch = "ptt-toggle"

    /// Local time the stamp was generated — effectively the build time.
    static let built = "2026-09-08 17:53"

    /// True when this binary was never stamped. Not a missing answer — it IS the answer:
    /// this build predates stamping, so it is older than any stamped one.
    static var isStamped: Bool { commit != "unstamped" }

    /// The build number — `CURRENT_PROJECT_VERSION`, which is the git commit count.
    ///
    /// ⚠️ READ FROM THE BUNDLE, NOT STAMPED INTO THIS FILE. It is already written into
    /// the project by `Scripts/stamp-build.sh`, and a second copy here could disagree
    /// with the first. One source, so there is nothing to keep in step.
    static var number: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
    }
}
