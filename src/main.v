module main

import os
import flag
import net.http
import regex
import term
import time

const base_url = 'https://www.royalroad.com'
const royal_road = ' ___               _   ___              _\n| _ \\___ _  _ __ _| | | _ \\___  __ _ __| |\n|   / _ \\ || / _` | | |   / _ \\/ _` / _` |\n|_|_\\___/\\_, \\__,_|_| |_|_\\___/\\__,_\\__,_|\n       |__/\n'
// 1 is brightest, 5 is darkest
const color_1 = 0xe8ede4
const color_2 = 0xd9e8cf
const color_3 = 0xd1e1c6
const color_4 = 0xbdd3ae
const color_5 = 0xa8c082

// Custom escape for obsidian
fn chapter_escape(input string) string {
	return name_chapter(input).replace(' ', '%20')
}

// Ensure file is not read as folder
fn name_chapter(input string) string {
	return input.trim_space_right().replace('/', '⧸').replace(':', '։')
}

// Find all unicodes in input string that are in the format \u0000
// Returns in the fomrat 0000
fn get_unicodes(input string) []string {
	mut unicodes := []string{}

	for i, c in input {
		if i + 5 >= input.len {
			break
		}
		if c == `\\` && input[i + 1] == `u` {
			unicodes << input[i + 2..i + 6]
		}
	}

	return unicodes
}

fn main() {
	mut fp := flag.new_flag_parser(os.args)

	// Info
	fp.application('rr-dl')
	fp.version('1.2.7')
	fp.description('A cli program for downloading novels from royalroad.com')
	fp.skip_executable()

	// Flags and arguments
	is_select_all := fp.bool('all', `a`, false, 'Select all chapters')
	is_add_title := fp.bool('title', `t`, false, 'Add chapter title to start of file')
	indexing_start := fp.int('indexing', `I`, 0, 'Index chapters starting from value')
	is_indexed := if indexing_start == 0 {
		fp.bool('index', `i`, false, 'Prefix title with chapter index')
	} else {
		fp.bool('index', `i`, true, 'Prefix title with chapter index')
	}
	download_directory := fp.string('directory', `d`, '.', 'Set download location')
	file_extension := fp.string('extension', `e`, 'md', 'Change file extension from md')

	searched_title_args := fp.finalize() or {
		println(fp.usage())
		exit(1)
	}
	searched_title := if searched_title_args.len == 0 {
		os.input(term.hex(color_3, 'Enter search title: '))
	} else {
		'${searched_title_args.join(' ')}'
	}

	// Get response text of search query
	mut search_string := base_url + '/fictions/search?'
	if searched_title.len != 0 {
		search_string += 'title=' + searched_title
	}
	resp_search := http.get_text(search_string)

	// Get hrefs for fictions and chapter counts per fiction
	mut re_fiction_hrefs := regex.regex_opt(r'<h2 class="fiction-title">(.*)</h2>') or {
		panic(err)
	}
	mut fiction_hrefs := re_fiction_hrefs.find_all_str(resp_search)
	mut re_fiction_chapter_counts := regex.regex_opt(r'<i class="fa fa-list" aria-hidden="true">(.*)</span>') or {
		panic(err)
	}
	mut fiction_chapter_counts := re_fiction_chapter_counts.find_all_str(resp_search)
	for i, href in fiction_hrefs {
		fiction_hrefs[i] = href.find_between(r'<a href="', r'" class="font-red-sunglo bold">')
		fiction_chapter_counts[i] = fiction_chapter_counts[i].find_between(r'<span>',
			r' Chapters</span>')
		fiction_chapter_counts[i] += if fiction_chapter_counts[i] == '1' {
			' Chapter'
		} else {
			' Chapters'
		} // Plural
	}

	// Get titles of fictions and fix unicode characters
	mut re_fiction_titles := regex.regex_opt(r'class="font-red-sunglo bold">(.*)</a>') or {
		panic(err)
	}
	mut fiction_titles := re_fiction_titles.find_all_str(resp_search)
	mut re_unicode_runes := regex.regex_opt(r'&#x([A-Za-z0-9]+);') or { panic(err) }
	for i, _ in fiction_titles {
		fiction_titles[i] = fiction_titles[i].find_between('>', '<')
		unicode_runes := re_unicode_runes.find_all_str(fiction_titles[i])
		for r in unicode_runes {
			fiction_titles[i] = fiction_titles[i].replace(r, (rune(('0x' + r[3..r.len - 1]).int())).str()).replace('&quot;',
				'"') // Replace with encoded version of unicode character
		}
	}

	// Print fiction info
	println('') // Leave space before and after print
	for i, _ in fiction_titles {
		println(term.hex(color_4, '[') + term.hex(color_2, '${i}') + term.hex(color_4, ']') +
			term.hex(color_5, ' ${fiction_titles[i]} ') +
			term.hex(color_1, '(${fiction_chapter_counts[i]})'))
	}
	println('')

	// Prompt for index of selection
	selected_fiction_title_index_str := match fiction_titles.len {
		0 { '-1' }
		1 { '0' }
		else { os.input_opt(term.hex(color_3, 'Select fiction by index: ')) or { '0' } }
	}

	selected_fiction_title_index := selected_fiction_title_index_str.int()
	if !(0 <= selected_fiction_title_index && selected_fiction_title_index <= fiction_titles.len - 1) {
		println(term.fail_message('ERROR: No fictions found'))
		exit(1)
	}

	// Keep selection in seperate variables for convenience
	selected_fiction := fiction_titles[selected_fiction_title_index]
	selected_href := fiction_hrefs[selected_fiction_title_index]
	selected_fiction_chapter_count := fiction_chapter_counts[selected_fiction_title_index]

	// Get names, slugs, ids and dates of all chapters of selected fiction
	resp_fiction := http.get_text(base_url + selected_href)
	window_chapters := resp_fiction.find_between(r'window.chapters = [', r'];')
	mut re_chapter_titles := regex.regex_opt(r'"title":"(.*)"') or { panic(err) }
	mut chapter_titles := re_chapter_titles.find_all_str(window_chapters)
	mut re_chapter_slugs := regex.regex_opt(r'"slug":"(.*)"') or { panic(err) }
	mut chapter_slugs := re_chapter_slugs.find_all_str(window_chapters)
	mut re_chapter_dates := regex.regex_opt(r'"date":"(.*)"') or { panic(err) }
	mut chapter_dates := re_chapter_dates.find_all_str(window_chapters)
	mut re_chapter_ids := regex.regex_opt(r'"id":(.*),') or { panic(err) }
	mut chapter_ids := re_chapter_ids.find_all_str(window_chapters)
	for i in 0 .. chapter_titles.len {
		// Make sure chapter title unicode is correct (try not to understand)
		chapter_titles[i] = chapter_titles[i].find_between(r'":"', r'"')
		mut unicodes := get_unicodes(chapter_titles[i])
		for unicode in unicodes {
			chapter_titles[i] = chapter_titles[i].replace(('\\u' + unicode).str(), (rune(('0x' +
				unicode).int())).str())
		}
		// Indexing chapters
		if is_indexed {
			chapter_titles[i] = '${i + indexing_start} - ' + chapter_titles[i]
		}
		// Fix bad crop
		chapter_slugs[i] = chapter_slugs[i].find_between(r'":"', r'"')
		chapter_dates[i] = chapter_dates[i].find_between(r'":"', r'"')
		chapter_ids[i] = chapter_ids[i].find_between(r'"id":', r',')
	}

	// Print some fancy stuff
	print(term.hex(color_5, '\n${royal_road}') + term.hex(color_3, '\n\n${selected_fiction}') +
		term.hex(color_1, '\n${selected_fiction_chapter_count}\n\n') +
		term.hex(color_3, 'Latest Chapter:') + term.hex(color_1, '\n${chapter_titles.last()}\n\n'))

	// Define initial chapter ranges and select all or none
	mut chapter_begin := if is_select_all { 0 } else { -1 }
	mut chapter_end := if is_select_all { chapter_titles.len - 1 } else { -1 }

	// Get chapter range by prompting user (could mabye be shortened to 2 function calls)
	if !is_select_all {
		mut chapter_search := []int{}

		search_chapter_begin := os.input(term.hex(color_3, 'Search for start chapter: '))
		println('')

		for i in 0 .. chapter_titles.len {
			if chapter_titles[i].contains(search_chapter_begin) {
				chapter_search << i
			}
		}

		if chapter_search.len == 0 {
			println(term.fail_message('ERROR: No results found'))
			exit(1)
		}

		for i, n in chapter_search {
			println(term.hex(color_4, '[') + term.hex(color_2, '${i}') + term.hex(color_4, ']') +
				term.hex(color_5, ' ${chapter_titles[n]}'))
		}

		chapter_begin_str := if chapter_search.len == 1 { '0' } else { os.input_opt(term.hex(color_3, '\nSelect start chapter by index / first result: ')) or {
				'0'} }
		chapter_begin = if chapter_search.len >= chapter_begin_str.int()
			&& chapter_begin_str.int() >= 0 {
			chapter_search[chapter_begin_str.int()]
		} else {
			panic(term.fail_message('ERROR: Selected chapter out of range'))
		}

		mut chapter_search_end := []int{}

		search_chapter_end := os.input(term.hex(color_3, '\nSearch for end chapter: '))
		println('')

		for i in 0 .. chapter_titles.len {
			if chapter_titles[i].contains(search_chapter_end) {
				chapter_search_end << i
			}
		}

		for i, n in chapter_search_end {
			println(term.hex(color_4, '[') + term.hex(color_2, '${i}') + term.hex(color_4, ']') +
				term.hex(color_5, ' ${chapter_titles[n]}'))
		}

		chapter_end_str := if chapter_search_end.len == 1 { '' } else { os.input_opt(term.hex(color_3, '\nSelect end chapter by index / single chapter: ')) or {
				chapter_begin.str()} }
		chapter_end = match chapter_search_end.len {
			0 {
				panic(term.fail_message('ERROR: No results found'))
				-1
			}
			1 {
				chapter_search_end[0]
			}
			else {
				if chapter_search_end.len <= chapter_end_str.int() && chapter_end_str.int() >= 0 {
					chapter_search[chapter_end_str.int()]
				} else {
					chapter_begin
				}
			}
		}

		if chapter_end < chapter_begin {
			panic(term.fail_message('ERROR: End chapter is before beginning chapter'))
		}
	}

	// Chapter ranges
	mut range := []int{}
	if chapter_begin == chapter_end {
		println(term.hex(color_5, 'Downloading chapter') + term.hex(color_3, ' ${chapter_begin}'))
		range << chapter_begin
	} else {
		println(term.hex(color_5, 'Downloading chapters') +
			term.hex(color_3, ' ${chapter_begin} ') + term.hex(color_5, 'to') +
			term.hex(color_3, ' ${chapter_end}') + term.hex(color_5, ':'))
		for i in chapter_begin .. chapter_end + 1 { // For loops cannot loop inclusively
			range << i // This is very dumb
		}
	}

	// Setup timer for downloads
	mut download_timer := time.new_stopwatch()

	// Download chapters in range
	for i in range {
		chapter_link := base_url + selected_href + '/chapter/' + chapter_ids[i] + '/' +
			chapter_slugs[i]
		println(term.hex(color_5, 'Downloading:') + ' ${term.hex(color_3, chapter_titles[i])}')
		println(term.hex(color_3, 'Link:') + ' ${term.hex(color_1, chapter_link)}')

		resp_chapter := http.get_text(chapter_link)

		mut chapter_content := resp_chapter.find_between(r'<div class="chapter-inner chapter-content">',
			r'<div class="portlet light').trim_space().trim_string_right('</div>')

		// Remove copy protection
		mut replace_class := ''
		for j, line in resp_chapter.split_into_lines() {
			if line.contains('display: none;') {
				replace_class = resp_chapter.split_into_lines()[j - 1].find_between('.',
					'{')
				break
			}
		}

		// Remove invisible class if present (safe goto with breaks?)
		for {
			replace_class_start := chapter_content.index('<span class="${replace_class}">') or {
				println(term.bg_yellow('WARNING: Class "' + replace_class + '" not found'))
				break
			}
			if replace_class_end := chapter_content.index_after('</span>', replace_class_start) {
				replace_class_str := chapter_content.substr(replace_class_start, replace_class_end)
				chapter_content = chapter_content.replace(replace_class_str, '').replace('</p></span>',
					'</p>')
			}
			break
		}

		// Add title to chapter
		if is_add_title {
			chapter_content = '# ${name_chapter(chapter_titles[i])}\n' + chapter_content
		}

		if i != range.last() {
			chapter_content += '\n[${name_chapter(chapter_titles[i + 1])}](${chapter_escape(chapter_titles[
				i + 1])})'
		}

		if os.is_writable(download_directory) {
			os.write_file(download_directory + '/' + name_chapter(chapter_titles[i]) + '.' +
				file_extension, chapter_content) or { panic(err) }
		} else {
			panic(term.fail_message('ERROR: Insufficient permissons to write to specified directory'))
		}
	}
	// Print elapsed time during downloade
	println(term.hex(color_3, '\nFinished download in ') +
		term.hex(color_1, '${download_timer.elapsed().milliseconds()}') + term.hex(color_3, 'ms'))
}
