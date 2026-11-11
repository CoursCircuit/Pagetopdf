-- Pages Apple event codes from Pages.sdef: export Pgst/expo,
-- destination pfil, format exft, PDF Ppdf. These allow compilation without Pages.
on exportpdf(pagesPath, inputPath, outputPath)
	set inputFile to POSIX file inputPath as alias
	set outputFile to POSIX file outputPath
	set openedHere to false
	set targetDoc to missing value
	tell application pagesPath
		repeat with candidate in documents
			set candidateFile to «class file» of candidate
			if candidateFile is not missing value then
				if (candidateFile as alias) = inputFile then
					set targetDoc to contents of candidate
					exit repeat
				end if
			end if
		end repeat
		try
			if targetDoc is missing value then
				set targetDoc to open inputFile
				set openedHere to true
			end if
			with timeout of 600 seconds
				«event Pgstexpo» targetDoc given «class pfil»:outputFile, «class exft»:«constant PgefPpdf»
			end timeout
		on error errorText number errorNumber
			if openedHere then
				try
					close targetDoc saving no
				end try
			end if
			error errorText number errorNumber
		end try
		if openedHere then close targetDoc saving no
	end tell
end exportpdf
