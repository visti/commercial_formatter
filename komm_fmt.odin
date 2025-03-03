package komm_fmt

import "core:fmt"
import io "core:io"
import "core:log"
import "core:mem"
import "core:os"
import str "core:strings"
import "core:unicode/utf8"

DEBUG :: false

REJECTFILE :: "rejected.csv"

// ERROR MESSAGES
NOTVALIDSTATION :: "ERROR: No valid station selected as argument."

station :: struct {
	name:         string,
	filename:     string,
	positions:    []int,
	stopwords:    []string,
	ext:          []string,
	hasHeadlines: bool,
	headlines:    []string,
}

Stations := []station{Bauer, Jyskfynske, Globus}

Globus := station {
	name         = "Globus",
	filename     = "",
	ext          = {"txt"},
	hasHeadlines = false,
	stopwords    = {},
	headlines    = {},
	positions    = {},
}

Jyskfynske := station {
	name         = "Jyskfynske",
	ext          = {"txt", "den"},
	hasHeadlines = false,
	positions    = {297, 291, 288, 267, 216, 200, 149, 98, 47, 37, 28, 27, 20, 11},
}

Bauer := station {
	name         = "Bauer",
	filename     = "",
	positions    = {185, 179, 173, 168, 163, 153, 128, 78, 28, 19, 14, 6},
	hasHeadlines = false,
	ext          = {"txt"},
	stopwords    = {
		"R1 ",
		" R1 ",
		"TOP HOUR",
		"99999998",
		"VO *:",
		"jingle",
		"SWEEPER",
		";SOFT ",
		"RADIO SOFT",
		"MR SW",
		";MR",
		"BREAKER",
		"NYHEDER",
		"PROMO",
		"VEJR",
		"Bauer",
	},
	headlines    = {
		"Date of Broadcasting",
		"Track starting time",
		"Track playing time",
		"Local-ID;Track Title",
		"Main Artist",
		"Record Label",
		"GramexID",
		"Side",
		"Tracknummer",
		"Country of Recording",
		"Year of first release",
		"ISRC-Code",
	},
}

printstation :: proc(station: station) {
	fmt.printf(
		"Name: %v\nPositions: %v\nFilename:%v\nStopwords:\n",
		station.name,
		station.positions,
		station.filename,
	)

	for word in station.stopwords {
		fmt.printf("%v\n", word)
	}
}

get_files :: proc(ext: []string) -> []string {
	outputFiles: string
	a: []string

	cwd := os.get_current_directory()
	f, err := os.open(cwd)
	defer os.close(f)

	files, _ := os.read_dir(f, 1)

	for fi in files {
		for x in ext {
			lowercaseFilename := str.to_lower(fi.name)
			if str.contains(lowercaseFilename, x) {
				a := []string{outputFiles, fi.name}
				outputFiles = str.join(a, ";")
			}
		}
	}
	if len(outputFiles) == 0 {
		info("", "No eligible files found.")
		os.exit(1)
	}


	info("Found Files", outputFiles[1:])
	db([]string, str.split(outputFiles[1:], ";"))
	return str.split(outputFiles[1:], ";")
}

info :: proc(field: string, string: string) {
	fmt.println("---------------------")
	fmt.printf("%v: %v\n", field, string)
	fmt.println("---------------------\n")
}

ask_user_stationtype :: proc() -> station {
	choice := str.to_upper(os.args[1])
	switch choice {
	case "BAUER":
		info("STATION: ", choice)
		return Bauer
	case "JYSKFYNSKE":
		info("STATION: ", choice)
		return Jyskfynske
	case:
		fmt.printf("%v\n", NOTVALIDSTATION)
		os.exit(1)

	}
	return station{}

}

ask_output_filename :: proc(currentStation: ^station) {
	buf: [256]byte
	fmt.println("Set output filename: ")
	n, err := os.read(os.stdin, buf[:])

	if err != nil {
		fmt.eprintln("Error: ", err)
	}

	if string(buf[:n]) == "" {
		fmt.eprintln("ERROR: Output filename cannot be empty!")
		os.exit(1)
	}

	currentStation.filename = str.clone(str.trim_space(string(buf[:n])))
}

// Main entry point.
main :: proc() {
	zonks: string = ""

	stationChoice := ask_user_stationtype()

	ask_output_filename(&stationChoice)
	defer delete(stationChoice.filename)
	outputFile := stationChoice.filename

	if outputFile == "" {
		fmt.eprintln("ERROR: Filename empty in main function.")
		os.exit(1)
	}

	if os.is_file(outputFile) {
		err := os.remove(outputFile)

		if err == nil {
			db(string, "Initialized output file.")
		}}
	os.write_entire_file(outputFile, transmute([]byte)(zonks))

	if len(os.args) == 1 {
		fmt.printf("Provide at least one argument.\n")
		fmt.printf("args: %v\n")
		for station in Stations {
			fmt.printf("Implemented types: %v\n", station.name)
		}

		return
	}


	filelist := get_files(stationChoice.ext)
	newFile := read_file(filelist)
	process_files(&newFile, stationChoice, outputFile)
}


read_file :: proc(files: []string) -> string {
	joinedFiles: string

	for file in files {
		data, ok := os.read_entire_file(file, context.allocator)

		if !ok {
			panic("Could not read file.")
		}
		defer delete(data, context.allocator)

		it := string(data)

		a := []string{joinedFiles, it}
		joinedFiles = str.concatenate(a)

	}
	return joinedFiles
}

db :: proc($T: typeid, value: T) {
	if DEBUG {
		fmt.printf("DEBUG: %v\n", value)
	}
}

clean_files :: proc(rejection_file: os.Handle, outputfile: os.Handle) {
	a := []os.Handle{rejection_file, outputfile}
	for file in a {
		path, _ := os.absolute_path_from_handle(file)
		slicePath := str.split(path, "/", context.allocator)
		db(string, path)
		size, err := os.file_size(file)
		if err == nil {
			if size == 0 {
				os.remove(path)
				fmt.printf("Removed empty file: %v\n", slicePath[len(slicePath) - 1])
			}
		}}
}

check_for_stopwords :: proc(file: os.Handle, line: string, currentStation: station) -> string {
	for word in currentStation.stopwords {
		if str.contains(line, word) {
			a := []string{line, "\n"}
			os.write_string(file, str.concatenate(a))
			return "REJECT"
		} else {return line}
	}
	return "REJECT"
}

wrap_up :: proc(rejected: int, processed: int) {
	fmt.printf("Processed Lines: %v\n", processed)
	fmt.printf("Rejected Lines: %v\n", rejected)
}


process_files :: proc(file: ^string, currentStation: station, outputFile: string) {
	modifiedLine: [dynamic]string
	headlinesOut: string
	zonks: string
	rejected: int
	processed: int

	//create rejection file
	os.write_entire_file(REJECTFILE, transmute([]byte)(zonks))

	if !os.is_file(REJECTFILE) {
		fmt.eprintln("ERROR: File was not created:", outputFile)
		os.exit(1)
	}
	rejectionFile, rejectfile_open_error := os.open(REJECTFILE, 2)


	outputFileHandle, err := os.open(outputFile, os.O_CREATE | os.O_WRONLY | os.O_TRUNC)
	if err != nil {
		fmt.eprintln("ERROR: could not create output file:", err)
	}
	defer os.close(outputFileHandle)

	if !currentStation.hasHeadlines {
		headlinesJoined := str.join(currentStation.headlines, ";")
		a := []string{headlinesJoined, "\n"}
		os.write_string(outputFileHandle, str.concatenate(a))
	}

	if err != nil {
		fmt.printf("%v\n", err)
	}

	for line in str.split_lines_iterator(file) {
		parts: [dynamic]string
		start: int

		checkedLine := check_for_stopwords(rejectionFile, line, currentStation)

		if checkedLine != "REJECT" {
			#reverse for position in currentStation.positions {
				part := (string)(checkedLine)[start:position]
				trimmedPart := str.trim_space(part)
				append(&parts, trimmedPart)
				start = position
			}
			processed += 1
		} else {rejected += 1}

		// construct output line from parts
		if checkedLine != "REJECT" {
			append(&parts, checkedLine[start:])
			modifiedLine := str.join(parts[:], ";")
			outputLine := str.join([]string{modifiedLine, "\n"}, "")
			_, err := os.write_string(outputFileHandle, outputLine)
		}

		if err != nil {
			fmt.printf("%v\n", err)
		}
	}
	wrap_up(rejected, processed)

	clean_files(rejectionFile, outputFileHandle)
}
