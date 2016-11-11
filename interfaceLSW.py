#!/usr/bin/python
# -*- coding: utf-8 -*-
#************************************************************
#
#                       IMITATOR
# 
# LIPN, Université Paris 13, Sorbonne Paris Cité (France)
# 
# Script description: interface between IMITATOR and Lin Shang-Wei's learning-based tool
# 
# File contributors : Étienne André
# Created           : 2016/11/07
# Last modified     : 2016/11/11
#************************************************************

# ###
# NOTE: parameters must be:
# 1) file name of the model
# 2) parameter valuation in the form "param1=value1,param2=value2…" (WARNING: no check is made here!)
				# 2) expected name of the transformed model (abstraction or counter-example) # NOTE: removed (for now)
# NOTE: the major assumptions for this interface to work are:
# - for each event a, a clock clock_a is defined; this clock must be reset everytime a is taken
# - parameter names should not overlap each other (nor should they overlap any other string in the model)
# - the model must contain some tags (special comments to delimit component A, component B, etc.)
# - the model should not contain the keyword 'automaton' anywhere else than in the 'automaton <automaton name>' syntax (even as a substring)
# - all initial location names should be different
# ###

#************************************************************
# MODULES
#************************************************************
import time
import datetime
import os
import sys
import subprocess
import re



#************************************************************
# GENERAL CONFIGURATION
#************************************************************

# Name for the larning binary
THIS_SCRIPT_NAME = 'Interfaçator'

# Name for the learning binary
LEARNING_BINARY_NAME = './learninglsw'

DEBUG_MODE = True
#DEBUG_MODE = False


#************************************************************
# TAGS
#************************************************************

# Tags to allow for finding various components
# NOTE: needed only by this script (and of course in the input models)
TAG_COMPONENT_A_START = '\\(\\* --- BEGIN COMPONENT A --- \\*\\)'
TAG_COMPONENT_A_END = '\\(\\* --- END COMPONENT A --- \\*\\)'
TAG_COMPONENT_B_START = '\\(\\* --- BEGIN COMPONENT B --- \\*\\)'
TAG_COMPONENT_B_END = '\\(\\* --- END COMPONENT B --- \\*\\)'
TAG_SPECIFICATION_START = '\\(\\* --- BEGIN SPECIFICATION --- \\*\\)'
TAG_SPECIFICATION_END = '\\(\\* --- END SPECIFICATION --- \\*\\)'

# Tags for interfacing with IMITATOR
# NOTE: needed by both this script and IMITATOR
TAG_ABSTRACTION = "===ABSTRACTION==="
TAG_COUNTEREXAMPLE = "===COUNTEREXAMPLE==="

# Separators in the pi0
SEPARATOR_PI0_PAIRS = ','
SEPARATOR_PI0_ASSIGNEMENT = '='

# Keywords in IMITATOR syntax
KEYWORD_AUTOMATON = 'automaton'
KEYWORD_LOC = 'loc'

# Keywords in LSW syntax
KEYWORD_INIT = 'INIT'

# Expected extension for input model (if different, another extension will be appended)
IMI_EXTENSION = '.imi'

# Extension for output model
LSW_EXTENSION = '.lsw'


#************************************************************
# GENERAL FUNCTIONS
#************************************************************

def print_to_screen(content):
	# Revert stdout
	#sys.stdout = orig_stdout
	# Print
	print content
	# Put back stdout to log file
	#sys.stdout = logfile


def fail_with(text) :
	print_to_screen('Fatal error!')
	print_to_screen(text)
	sys.exit(1)


# Check whether a binary exists (and is executable)
def binary_exists(binary_name):
	return os.path.isfile(binary_name) and os.access(binary_name, os.X_OK)

# Get the content of a file in the form of a unique string
def read_file_content(file_name):
	with open(file_name, 'r') as myfile:
		data = myfile.read() #.replace('\n', '')
		return data

def write_file_content(file_name, content):
	file = open(file_name, 'w')
	file.write(content)
	file.close()
	return

# Find the content of a string between two delimiters; aborts if substring not found
def find_substring_within_delimiters(string, delimiter_start, delimiter_end):
	# NOTE: 're.DOTALL' allows to match newline characters inside '.'
	m = re.search(delimiter_start + '(.+?)' + delimiter_end, string, re.DOTALL)
	if m:
		return m.group(1)
	else:
		fail_with('Could not find substring within delimiters "' + delimiter_start + '" and "' + delimiter_end + '"')


# Find the content of a string after one delimiter; aborts if substring not found
def find_substring_after_delimiter(string, delimiter):
	# NOTE: 're.DOTALL' allows to match newline characters inside '.'
	m = re.search(delimiter + '(.+?)$', string, re.DOTALL)
	if m:
		return m.group(1)
	else:
		fail_with('Could not find substring after delimiter "' + delimiter + '"')


#************************************************************
# MODEL CUT+PASTE FUNCTIONS
#************************************************************

#------------------------------------------------------------
# Get the string representing IMITATOR format for component A (parametric)
#------------------------------------------------------------
def get_component_A(model):
	return find_substring_within_delimiters(model, TAG_COMPONENT_A_START, TAG_COMPONENT_A_END)

#------------------------------------------------------------
# Get the string representing IMITATOR format for component B (non-parametric)
#------------------------------------------------------------
def get_component_B(model):
	return find_substring_within_delimiters(model, TAG_COMPONENT_B_START, TAG_COMPONENT_B_END)

#------------------------------------------------------------
# Get the string representing IMITATOR format for the specification
#------------------------------------------------------------
def get_specification(model):
	return find_substring_within_delimiters(model, TAG_SPECIFICATION_START, TAG_SPECIFICATION_END)

#------------------------------------------------------------
# Get the string representing the initial definitions in the IMITATOR model
#------------------------------------------------------------
def get_init_definition(model):
	# NOTE: everything after TAG_SPECIFICATION_END should be the init definition
	return find_substring_after_delimiter(model, TAG_SPECIFICATION_END)


#------------------------------------------------------------
# Get all automata names in a component, i.e., all strings following KEYWORD_AUTOMATON
# WARNING: this keyword should not be used elsewhere, even as a substring or in a comment!
#------------------------------------------------------------
def get_automata_names(component):
	# NOTE: \w matches any alphanumeric character; this is equivalent to the class [a-zA-Z0-9_]
	return re.findall(KEYWORD_AUTOMATON + '\s+(\w+)', component)


#------------------------------------------------------------
# Compute a dictionary automaton_name => initial location_name
# WARNING: this is based on string matching, so it is best that a single occurrence of loc[automaton_name] = location_name is defined (included in comments!)
# NOTE: it is OK if this is defined (in comments) for non-existing PTA
#------------------------------------------------------------
def compute_initial_locations(init_definition):
	# NOTE: look for "& loc[automaton_name] = location_name"
	# NOTE: \w matches any alphanumeric character; this is equivalent to the class [a-zA-Z0-9_]
	matches = re.findall('\&\s' + KEYWORD_LOC + '\[(\w+)\]\s*=\s*(\w+)', init_definition)
	
	# Create dictionary automaton_name => initial location_name
	initial_locations = {}
	
	for _, (automaton_name, location_name) in enumerate(matches):
		# Add binding automaton_name => initial location_name
		initial_locations[automaton_name] = location_name
	
	return initial_locations

#------------------------------------------------------------
# Replace each parameter with its valuation as in pi0. Takes as second argument a list of pairs (parameter, valuation)
# WARNING: this is based on string replacing, so parameter names should not overlap each other (nor should they overlap any other string in the model)
#------------------------------------------------------------
def valuate_component(component, pi0):
	new_component = component
	# Replace each pair
	for (parameter, valuation) in pi0:
		new_component = new_component.replace(parameter, str(valuation))
	return new_component

#------------------------------------------------------------
# Add the 'KEYWORD_INIT' tag to all initial locations
# WARNING: this is based on string replacing, so location names should not overlap each other
#------------------------------------------------------------
def add_INIT_locations(component, component_automata, initial_locations):
	
	# Iterate on the component automata
	for automaton_name in component_automata:
		# Find the initial location for automaton
		initial_location = initial_locations[automaton_name]
		
		# Replace 'loc location' with 'loc location[INIT]'
		
		print 'Replace "loc ' + initial_location + '" with "loc ' + initial_location + '[INIT]"'
		
		new_component = re.sub(KEYWORD_LOC + '\s+' + initial_location, KEYWORD_LOC + ' ' + initial_location + '[' + KEYWORD_INIT + ']', component)
		#new_component = re.sub(initial_location, initial_location + '[' + KEYWORD_INIT + ']', component)
		
		# Check
		if new_component == component:
			fail_with('Could not find pattern "loc ' + initial_location + '" in automaton "' + automaton_name + '"')
		component = new_component
	
	return new_component


#------------------------------------------------------------
# Create the line in the form 'EMPTY CHECKING: {Input, DummyERA} || {Output, DummyERA2} || Spec'
#------------------------------------------------------------
def create_analysis_line(component_A, component_B, specification):
	return 'EMPTY CHECKING: {' + ', '.join(component_A) + '} || {' + ', '.join(component_B) + '} || ' + ', '.join(specification) + ''
	

#************************************************************
# PRELIMINARY CHECKS
#************************************************************

print_to_screen('Hello, this is ' + THIS_SCRIPT_NAME + '!')


# Check that the learning binary exists
if not binary_exists(LEARNING_BINARY_NAME) :
	fail_with('Binary "' + LEARNING_BINARY_NAME + '" does not exist')


if len(sys.argv) <> 3:
	fail_with("Exactly 2 arguments are expected")


#************************************************************
# MAIN FUNCTION
#************************************************************

# Get the IMITATOR model name
original_model_name = sys.argv[1]

# Get the expected transformed model name
#new_model_name = sys.argv[2]

# Get pi0 (as a string)
pi0_string = sys.argv[2]


if DEBUG_MODE:
	print "\nArgument 1 = original model name:"
	print original_model_name
	#print "\nArgument 2 = new model name:"
	#print new_model_name
	print "\nArgument 2 = pi0:"
	print pi0_string


#------------------------------------------------------------
# Load model
#------------------------------------------------------------
if not os.path.isfile(original_model_name):
	fail_with('Original model "' + original_model_name + '" does not exist')

model = read_file_content(original_model_name)

if DEBUG_MODE:
	print "\nModel:"
	print model


#------------------------------------------------------------
# Find components
#------------------------------------------------------------
print "Finding components A and B…"
component_A = get_component_A(model)
component_B = get_component_B(model)
print "Finding specification…"
specification = get_specification(model)
print "Finding init definition…"
init_definition = get_init_definition(model)

if DEBUG_MODE:
	print "\nComponent A:"
	print component_A
	print "\nComponent B:"
	print component_B
	print "\nSpecification:"
	print specification
	print "\nInit definition:"
	print init_definition

#------------------------------------------------------------
# Find automata names
#------------------------------------------------------------
print "Finding automata names…"
automata_names_in_A = get_automata_names(component_A)
print '    In A: ' + str(automata_names_in_A)
automata_names_in_B = get_automata_names(component_B)
print '    In B: ' + str(automata_names_in_B)
automata_names_in_specification = get_automata_names(specification)
print '    In the specification: ' + str(automata_names_in_specification)

#------------------------------------------------------------
# Find initial locations
#------------------------------------------------------------
print "Gathering initial locations…"
# Compute dictionary automaton_name => initial location_name
initial_locations = compute_initial_locations(init_definition)

if DEBUG_MODE:
	for automaton_name, location_name in initial_locations.items():
		print '    loc[' + automaton_name + ']=' + location_name + ''


#fail_with('bye for now')

#------------------------------------------------------------
# Find and analyse pi0
#------------------------------------------------------------
print "Building reference valuation…"

# Split into assignments
pi0_assignments = re.split(SEPARATOR_PI0_PAIRS , pi0_string)

# Build up a list of pairs (parameter, valuation)
pi0_pairs = []
for idx, pair in enumerate(pi0_assignments):
	#print pair
	split_pair = re.split(SEPARATOR_PI0_ASSIGNEMENT, pair)
	# Check that this is a pair
	if len(split_pair) <> 2:
		fail_with('Pair "' + str(split_pair) + '" should be of the form "parameter' + SEPARATOR_PI0_ASSIGNEMENT + 'valuation"')
	# Get pair elements
	parameter = split_pair[0]
	valuation = split_pair[1]
	# Add pair to the new list
	pi0_pairs.append((parameter , valuation))

# Print pi0
print 'Pi0:'
for (parameter, valuation) in pi0_pairs:
	print '    v(' + parameter + ') = ' + str(valuation)

#------------------------------------------------------------
# Prepare the model for the learning tool
#------------------------------------------------------------
print "Valuating component A with pi0…"

# Replace parameters with their valuation defined in pi0
component_vA = valuate_component(component_A, pi0_pairs)

if DEBUG_MODE:
	print "\nv(A):"
	print component_vA

# Prepare the analysis line
analysis_line = create_analysis_line(automata_names_in_A, automata_names_in_B, automata_names_in_specification)

# Create v(A) + B + the analysis line; also add initial locations
model_content = add_INIT_locations(component_vA, automata_names_in_A, initial_locations) + add_INIT_locations(component_B, automata_names_in_B, initial_locations) + add_INIT_locations(specification, automata_names_in_specification, initial_locations) + analysis_line

if DEBUG_MODE:
	print "\nTransformed model:"
	print model_content



#------------------------------------------------------------
# Building the exported file name: if original_model_name is 'file_name.imi', then it becomes 'file_name.lsw'; if original_model_name is 'model', then 'model.lsw'
#------------------------------------------------------------
exported_file_name = ''

# Try to find a pattern file_name.imi
m = re.search('(.+?)' + IMI_EXTENSION + '$', original_model_name)
if m:
	exported_file_name = m.group(1) + LSW_EXTENSION
else:
	exported_file_name = original_model_name + LSW_EXTENSION


#------------------------------------------------------------
# Writing content to file
#------------------------------------------------------------
print 'Writing content to "' + exported_file_name + '"…'
write_file_content(exported_file_name, model_content)






#------------------------------------------------------------
# TODO: call the learning tool
#------------------------------------------------------------
# Prepare the command (using a list form)
cmd = [LEARNING_BINARY_NAME] + [exported_file_name]
print_to_screen('Command : "' + ' '.join(cmd) + '"')
subprocess.call(cmd)


#------------------------------------------------------------
# TODO: retrieve the result
#------------------------------------------------------------


#------------------------------------------------------------
# TODO: if abstraction
#------------------------------------------------------------
if True:
	print_to_screen('Abstraction detected')

	# TODO: remove all "& loc[automaton_name] = location_name" for automata in B
	
	# TODO: add "& loc[Babs] = location_name"
	
	# TODO: build header + A + Babs + updated footer
	

#------------------------------------------------------------
# TODO: if counter-example
#------------------------------------------------------------
else:
	print_to_screen('Counter-example detected')
	# TODO: add "& loc[trace-automaton] = location_name"

	# TODO: build header + A + B + trace-automaton + updated footer


#------------------------------------------------------------
# Create file for IMITATOR
#------------------------------------------------------------
# TODO


#************************************************************
# THE END
#************************************************************

print_to_screen('')
print_to_screen('…The end of ' + THIS_SCRIPT_NAME + '!')

# Happy end
sys.exit(0)
