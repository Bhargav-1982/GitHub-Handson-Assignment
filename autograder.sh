#!/bin/bash
# Enhanced Autograder with Partial Credit Support
# Edit the variables below for each new assignment

# =============================================================================
# ASSIGNMENT SETTINGS (Edit these for each assignment)
# =============================================================================
ASSIGNMENT_NAME="Simple Calculator"
TOTAL_POINTS=100
COMPILATION_POINTS=10
TEST_POINTS=90
TIMEOUT_SECONDS=5

# Partial credit settings
ENABLE_PARTIAL_CREDIT=true
MIN_PARTIAL_CREDIT=0.1  # Minimum 10% credit if program runs without crashing
LINE_MATCH_WEIGHT=0.7   # 70% weight for line-by-line matching
OUTPUT_LENGTH_WEIGHT=0.3 # 30% weight for having reasonable output length
EXACT_MATCH_BONUS=0.05  # 5% bonus for exact character matching (even with different whitespace)

# Due date (Florida time) - Format: "YYYY-MM-DD HH:MM:SS"
DUE_DATE="2025-12-31 23:59:59"

# =============================================================================
# FILE SETTINGS
# =============================================================================
STUDENT_FILE="student_submission.c"
EXECUTABLE_NAME="run"

# =============================================================================
# COLORS FOR OUTPUT
# =============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# =============================================================================
# INITIALIZE SCORES
# =============================================================================
COMPILATION_SCORE=0
TEST_SCORE=0
TOTAL_TESTS=0
PASSED_TESTS=0
declare -a TEST_SCORES  # Array to store individual test scores

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️ $1${NC}"
}

print_partial() {
    echo -e "${YELLOW}⚡ $1${NC}"
}

# Function to calculate partial credit for a test case
calculate_partial_credit() {
    local test_num=$1
    local expected_file=$2
    local student_output=$3
    local crashed=$4
    
    # If program crashed, give minimal credit
    if [[ $crashed -eq 1 ]]; then
        echo "0.05"  # 5% credit for attempting
        return
    fi
    
    # If files don't exist, return 0
    if [[ ! -f "$expected_file" || ! -f "$student_output" ]]; then
        echo "0"
        return
    fi
    
    # Check if outputs are identical (full credit)
    if diff -w -B "$expected_file" "$student_output" > /dev/null 2>&1; then
        echo "1.0"
        return
    fi
    
    # Calculate partial credit based on similarity
    local expected_lines=$(wc -l < "$expected_file" 2>/dev/null || echo "0")
    local student_lines=$(wc -l < "$student_output" 2>/dev/null || echo "0")
    local expected_chars=$(wc -c < "$expected_file" 2>/dev/null || echo "0")
    local student_chars=$(wc -c < "$student_output" 2>/dev/null || echo "0")
    
    # If student produced no output, minimal credit
    if [[ $student_lines -eq 0 && $student_chars -eq 0 ]]; then
        echo "$MIN_PARTIAL_CREDIT"
        return
    fi
    
    # Check for exact character match (ignoring whitespace) - bonus points
    local exact_bonus=0
    if diff -w -B -q "$expected_file" "$student_output" > /dev/null 2>&1; then
        exact_bonus=$EXACT_MATCH_BONUS
    fi
    
    # Calculate line-by-line similarity using diff
    local matching_lines=0
    local total_lines=$expected_lines
    
    if [[ $total_lines -gt 0 ]]; then
        # Count lines that match (ignoring whitespace)
        local temp_diff=$(mktemp)
        diff -w -B --unchanged-line-format="%L" --old-line-format="" --new-line-format="" "$expected_file" "$student_output" > "$temp_diff" 2>/dev/null
        matching_lines=$(wc -l < "$temp_diff" 2>/dev/null || echo "0")
        rm -f "$temp_diff"
    fi
    
    # Calculate similarity metrics
    local line_similarity=0
    if [[ $total_lines -gt 0 ]]; then
        line_similarity=$(echo "scale=3; $matching_lines / $total_lines" | bc -l 2>/dev/null || echo "0")
    fi
    
    # Calculate length similarity (penalize outputs that are way too long/short)
    local length_similarity=0
    if [[ $expected_chars -gt 0 ]]; then
        local length_ratio
        if [[ $student_chars -eq 0 ]]; then
            length_ratio=0
        elif [[ $student_chars -le $expected_chars ]]; then
            length_ratio=$(echo "scale=3; $student_chars / $expected_chars" | bc -l 2>/dev/null || echo "0")
        else
            length_ratio=$(echo "scale=3; $expected_chars / $student_chars" | bc -l 2>/dev/null || echo "0")
        fi
        length_similarity=$length_ratio
    fi
    
    # Weighted combination with bonus
    local partial_score=$(echo "scale=3; ($LINE_MATCH_WEIGHT * $line_similarity) + ($OUTPUT_LENGTH_WEIGHT * $length_similarity) + $exact_bonus" | bc -l 2>/dev/null || echo "0")
    
    # Ensure minimum credit if program ran and produced some output
    local min_check=$(echo "$partial_score < $MIN_PARTIAL_CREDIT" | bc -l 2>/dev/null || echo "1")
    if [[ $min_check -eq 1 && $student_chars -gt 0 ]]; then
        partial_score=$MIN_PARTIAL_CREDIT
    fi
    
    # Cap at 1.0
    local max_check=$(echo "$partial_score > 1.0" | bc -l 2>/dev/null || echo "0")
    if [[ $max_check -eq 1 ]]; then
        partial_score="1.0"
    fi
    
    echo "$partial_score"
}

# Function to display detailed differences with partial credit info
show_detailed_diff() {
    local test_num=$1
    local expected_file=$2
    local student_output=$3
    local partial_score=$4
    
    echo -e "${CYAN}📋 Detailed Difference Analysis:${NC}"
    
    # Show partial credit earned (rounded to nearest percent)
    percentage=$(echo "scale=0; ($partial_score * 100 + 0.5) / 1" | bc -l 2>/dev/null || echo "0")
    echo -e "${YELLOW}   Partial Credit Earned: ${percentage}%${NC}"
    
    # Create detailed diff
    local diff_file="Results/diff_${test_num}.txt"
    diff -u --label "Expected Output" --label "Your Output" "$expected_file" "$student_output" > "$diff_file" 2>/dev/null

    if [[ -s "$diff_file" ]]; then
        echo -e "${CYAN}    (- expected, + your output):${NC}"
        local line_count=0
        while IFS= read -r line && [[ $line_count -lt 10 ]]; do
            case "$line" in
                ---*|+++*|@@*)
                    continue ;;
                -*)
                    echo -e "${RED}   $line${NC}"
                    ((line_count++)) ;;
                +*)
                    echo -e "${GREEN}   $line${NC}"
                    ((line_count++)) ;;
                *)
                    if [[ $line_count -lt 8 ]]; then
                        echo "   $line"
                        ((line_count++))
                    fi ;;
            esac
        done < "$diff_file"
        
        if [[ $(wc -l < "$diff_file") -gt 15 ]]; then
            echo -e "${CYAN}   ... (output truncated, see Results/diff_${test_num}.txt for full diff)${NC}"
        fi
    fi
    
    # Show statistics and helpful info
    expected_lines=$(wc -l < "$expected_file" 2>/dev/null || echo "0")
    student_lines=$(wc -l < "$student_output" 2>/dev/null || echo "0")
    expected_chars=$(wc -c < "$expected_file" 2>/dev/null || echo "0")
    student_chars=$(wc -c < "$student_output" 2>/dev/null || echo "0")
    
    echo -e "${CYAN}   Statistics:${NC}"
    echo -e "${CYAN}     Lines: Expected=$expected_lines, Yours=$student_lines${NC}"
    echo -e "${CYAN}     Characters: Expected=$expected_chars, Yours=$student_chars${NC}"
    
    # Give helpful hints based on the type of difference
    if [[ $student_lines -eq 0 ]]; then
        echo -e "${YELLOW}   💡 Hint: Your program produced no output. Check if it's reading input correctly.${NC}"
    elif [[ $expected_lines -gt 0 && $student_lines -gt $((expected_lines * 2)) ]]; then
        echo -e "${YELLOW}   💡 Hint: You're producing too much output. Check for extra print statements or loops.${NC}"
    elif [[ $expected_lines -gt 0 && $student_lines -lt $((expected_lines / 2)) ]]; then
        echo -e "${YELLOW}   💡 Hint: You're producing too little output. Check if all required outputs are printed.${NC}"
    elif [[ $expected_chars -gt 0 && $student_chars -gt 0 ]]; then
        char_diff=$(echo "scale=0; ($student_chars - $expected_chars)" | bc -l 2>/dev/null || echo "0")
        if [[ ${char_diff#-} -lt 5 ]]; then  # Remove minus sign for absolute value
            echo -e "${YELLOW}   💡 Hint: Very close! Check for output mismatch, extra spaces, missing newlines, or small typos.${NC}"
        fi
    fi
    echo
}

# =============================================================================
# MAIN GRADING STARTS HERE
# =============================================================================
echo "🎯 Assignment: $ASSIGNMENT_NAME"
echo "📅 Student: ${GITHUB_ACTOR:-Unknown}"
echo "⏰ Submission: $(TZ='America/New_York' date '+%Y-%m-%d %H:%M:%S %Z')"
echo "🔧 Partial Credit: $([ "$ENABLE_PARTIAL_CREDIT" = true ] && echo "ENABLED" || echo "DISABLED")"
echo

# Create Results directory
mkdir -p Results

# Check if bc is available for calculations
if ! command -v bc &> /dev/null; then
    print_warning "bc not found - installing basic calculator functionality"
    # Create a simple bc replacement function for basic operations
    bc() {
        if [[ "$1" == "-l" ]]; then
            shift
        fi
        python3 -c "print(int($1))" 2>/dev/null || echo "0"
    }
fi

# =============================================================================
# STEP 1: CHECK IF STUDENT FILE EXISTS
# =============================================================================
echo
echo "📂 Checking files..."

if [[ ! -f "$STUDENT_FILE" ]]; then
    print_error "$STUDENT_FILE not found!"
    echo "Make sure your code is in a file named exactly: $STUDENT_FILE"
    exit 1
fi

print_success "Found $STUDENT_FILE"

# =============================================================================
# STEP 2: COMPILE THE CODE
# =============================================================================
echo
echo "🔨 Compiling your code..."

if [[ -f "Makefile" ]]; then
    print_info "Found Makefile, using make to compile..."
    if make 2> Results/compile_errors.txt; then
        print_success "Code compiled successfully using make!"
        COMPILATION_SCORE=$COMPILATION_POINTS
    else
        print_error "Code failed to compile with make"
        echo
        echo "Compilation errors:"
        cat Results/compile_errors.txt | head -10
        COMPILATION_SCORE=0
        FINAL_SCORE=$COMPILATION_SCORE
        echo
        echo "📊 FINAL GRADE: $FINAL_SCORE/$TOTAL_POINTS (Code must compile to get test points)"
        exit 1
    fi
else
    print_info "No Makefile found, using gcc directly..."
    if gcc -std=c17 -Wall -Wextra -Werror -pedantic -g -O0 "$STUDENT_FILE" -o "$EXECUTABLE_NAME" 2> Results/compile_errors.txt; then
        print_success "Code compiled successfully!"
        COMPILATION_SCORE=$COMPILATION_POINTS
    else
        print_error "Code failed to compile"
        echo
        echo "Compilation errors:"
        cat Results/compile_errors.txt | head -10
        COMPILATION_SCORE=0
        FINAL_SCORE=$COMPILATION_SCORE
        echo
        echo "📊 FINAL GRADE: $FINAL_SCORE/$TOTAL_POINTS (Code must compile to get test points)"
        exit 1
    fi
fi

# =============================================================================
# STEP 3: RUN TEST CASES WITH PARTIAL CREDIT
# =============================================================================
echo
echo "🧪 Running test cases..."

# Find all test input files
TEST_INPUTS=(Testing/Testcases/input*.txt)

if [[ ! -f "${TEST_INPUTS[0]}" ]]; then
    print_error "No test files found!"
    exit 1
fi

TOTAL_TESTS=${#TEST_INPUTS[@]}
echo "Found $TOTAL_TESTS test case(s)"
echo

# Initialize test scores array
for ((i=0; i<TOTAL_TESTS; i++)); do
    TEST_SCORES[i]=0
done

# Run each test
test_index=0
for input_file in "${TEST_INPUTS[@]}"; do
    # Get test number
    test_num=$(basename "$input_file" .txt | sed 's/input//')
    expected_file="Testing/Expected_Output/output${test_num}.txt"

    echo "🔍 Test $test_num:"
    
    if [[ ! -f "$expected_file" ]]; then
        print_warning "Expected output file missing: $expected_file"
        TEST_SCORES[$test_index]=0
        ((test_index++))
        continue
    fi
    
    # Run student's program
    student_output="Results/student_output_${test_num}.txt"
    timeout "$TIMEOUT_SECONDS" ./"$EXECUTABLE_NAME" < "$input_file" > "$student_output" 2>/dev/null
    exit_code=$?
    
    # Determine if program crashed
    crashed=0
    if [[ $exit_code -eq 124 ]]; then
        print_error "Test $test_num TIMEOUT"
        crashed=1
    elif [[ $exit_code -gt 128 ]]; then
        print_error "Test $test_num CRASHED"
        crashed=1
    fi
    
    # Calculate score for this test
    if [[ "$ENABLE_PARTIAL_CREDIT" = true ]]; then
        partial_score=$(calculate_partial_credit "$test_num" "$expected_file" "$student_output" "$crashed")
        TEST_SCORES[$test_index]=$partial_score
        
        # Display result
        if [[ $crashed -eq 1 ]]; then
            echo "   ⚠️ Program issue detected"
        elif [[ $(echo "$partial_score == 1.0" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
            print_success "Test $test_num PASSED (100%)"
            ((PASSED_TESTS++))
        else
            percentage=$(echo "scale=0; ($partial_score * 100 + 0.5) / 1" | bc -l 2>/dev/null || echo "0")
            print_partial "Test $test_num PARTIAL (${percentage}%)"
            show_detailed_diff "$test_num" "$expected_file" "$student_output" "$partial_score"
        fi
    else
        # Original all-or-nothing scoring
        if [[ $crashed -eq 0 ]] && diff -w -B "$expected_file" "$student_output" > /dev/null 2>&1; then
            print_success "Test $test_num PASSED"
            TEST_SCORES[$test_index]=1.0
            ((PASSED_TESTS++))
        else
            print_error "Test $test_num FAILED"
            TEST_SCORES[$test_index]=0
            if [[ $crashed -eq 0 ]]; then
                show_detailed_diff "$test_num" "$expected_file" "$student_output" "0"
            fi
        fi
    fi
    
    ((test_index++))
    echo
done

# =============================================================================
# STEP 4: CALCULATE FINAL GRADE WITH PARTIAL CREDIT
# =============================================================================

# Calculate total test score from partial scores
total_test_score=0
for score in "${TEST_SCORES[@]}"; do
    if [[ -n "$score" && "$score" != "0" ]]; then
        total_test_score=$(echo "$total_test_score + $score" | bc -l 2>/dev/null || echo "$total_test_score")
    fi
done

if [[ $TOTAL_TESTS -gt 0 ]]; then
    # Convert total partial score to points (rounded to nearest integer)
    TEST_SCORE=$(echo "scale=0; (($total_test_score * $TEST_POINTS) / $TOTAL_TESTS + 0.5) / 1" | bc -l 2>/dev/null || echo "0")
fi

FINAL_SCORE=$((COMPILATION_SCORE + TEST_SCORE))
PERCENTAGE=$((FINAL_SCORE * 100 / TOTAL_POINTS))

# =============================================================================
# STEP 5: DISPLAY ENHANCED RESULTS
# =============================================================================

echo "📊 GRADE SUMMARY"
echo "=========================="
echo "Compilation: $COMPILATION_SCORE/$COMPILATION_POINTS points"

if [[ "$ENABLE_PARTIAL_CREDIT" = true ]]; then
    echo "Tests:"
    for ((i=0; i<TOTAL_TESTS; i++)); do
        test_points=$(echo "scale=1; ${TEST_SCORES[i]} * $TEST_POINTS / $TOTAL_TESTS" | bc -l 2>/dev/null || echo "0")
        max_test_points=$(echo "scale=1; $TEST_POINTS / $TOTAL_TESTS" | bc -l 2>/dev/null || echo "0")
        percentage=$(echo "scale=1; ${TEST_SCORES[i]} * 100" | bc -l 2>/dev/null || echo "0")
        #printf "  Test %d:       %s/%s points (%.1f%%)\n" $((i+1)) "$test_points" "$max_test_points" 
        printf "  Test %d: %.1f%% points\n" $((i+1)) "$percentage"
    done
    #echo "Total Tests:  $TEST_SCORE/$TEST_POINTS points"
else
    echo "Tests Passed:    $PASSED_TESTS/$TOTAL_TESTS ($TEST_SCORE/$TEST_POINTS points)"
fi

echo "=========================="
echo "FINAL GRADE: $FINAL_SCORE/$TOTAL_POINTS ($PERCENTAGE%)"

# Motivational messages
if [[ $PERCENTAGE -ge 90 ]]; then
    echo -e "\n🎉 Excellent work!"
elif [[ $PERCENTAGE -ge 80 ]]; then
    echo -e "\n👍 Great job!"
elif [[ $PERCENTAGE -ge 70 ]]; then
    echo -e "\n✅ Good work!"
elif [[ $PERCENTAGE -ge 60 ]]; then
    echo -e "\n📚 Getting there - keep practicing!"
else
    echo -e "\n💪 Don't give up - review the feedback and try again!"
fi

echo
echo "💡 Remember: You can resubmit as many times as you want before the deadline!"
echo

# =============================================================================
# SAVE ENHANCED RESULTS
# =============================================================================

# Create machine-readable summary with partial scores
{
    echo "ASSIGNMENT: $ASSIGNMENT_NAME"
    echo "STUDENT: ${GITHUB_ACTOR:-Unknown}"
    echo "FINAL_SCORE: $FINAL_SCORE"
    echo "TOTAL_POINTS: $TOTAL_POINTS"
    echo "PERCENTAGE: $PERCENTAGE"
    echo "COMPILATION_SCORE: $COMPILATION_SCORE"
    echo "TEST_SCORE: $TEST_SCORE"
    echo "TESTS_PASSED: $PASSED_TESTS"
    echo "TOTAL_TESTS: $TOTAL_TESTS"
    echo "PARTIAL_CREDIT_ENABLED: $ENABLE_PARTIAL_CREDIT"
    echo "INDIVIDUAL_TEST_SCORES: ${TEST_SCORES[*]}"
    echo "TIMESTAMP: $(date)"
} > Results/summary.txt

exit 0