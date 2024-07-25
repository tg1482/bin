#!/bin/bash
set -e

# Function to display usage information
usage() {
    echo "Usage: $0 [--claude | --openai]"
    echo "  --claude    Use Claude (AWS Bedrock) for analysis (default)"
    echo "  --openai    Use GPT-4 (OpenAI) for analysis"
    exit 1
}

# Parse command-line arguments
AI_MODEL="claude"  # Default to Claude
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --aws) AI_MODEL="aws" ;;
        --claude) AI_MODEL="claude" ;;
        --openai) AI_MODEL="openai" ;;
        --help) usage ;;
        *) echo "Unknown parameter: $1"; usage ;;
    esac
    shift
done

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if required commands are available
for cmd in git gh jq curl aws; do
    if ! command_exists "$cmd"; then
        echo "Error: $cmd is not installed. Please install it and try again."
        exit 1
    fi
done

# Set API credentials based on the chosen AI model
if [ "$AI_MODEL" = "openai" ]; then
    if [ -z "$OPENAI_API_KEY" ]; then
        echo "Error: OPENAI_API_KEY is not set. Please set it and try again."
        exit 1
    fi
elif [ "$AI_MODEL" = "aws" ]; then
    # Claude (AWS Bedrock) credentials
    if [ -z "$AWS_ACCESS_KEY" ] || [ -z "$AWS_SECRET_KEY" ]; then
        echo "Error: AWS credentials are not set. Please set AWS_ACCESS_KEY and AWS_SECRET_KEY and try again."
        exit 1
    fi
    export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-"us-east-1"}
elif [ "$AI_MODEL" = "claude" ]; then
    if [ -z "$ANTHROPIC_API_KEY" ]; then
        echo "Error: ANTHROPIC_API_KEY is not set. Please set it and try again."
        exit 1
    fi
fi

# Get the current branch name
current_branch=$(git rev-parse --abbrev-ref HEAD)

# Check if there's an existing PR for the current branch
pr_number=$(gh pr list --head "$current_branch" --json number --jq '.[0].number')

if [ -z "$pr_number" ]; then
    echo "No existing PR found. Creating a new one..."
    pr_url=$(gh pr create --fill)
    pr_number=$(echo "$pr_url" | grep -oE '[0-9]+$')
else
    echo "Existing PR found: #$pr_number"
fi

# Get the base branch
base_branch=$(gh pr view "$pr_number" --json baseRefName --jq '.baseRefName')

# Get the diff
diff_output=$(git diff "origin/$base_branch...$current_branch")

# Get the list of changed files
changed_files=$(git diff --name-only "origin/$base_branch...$current_branch")

# Prepare the prompt for AI analysis
prompt="You are an expert code reviewer who follows the best practices, loves simple and elegant code, and is always looking for ways to improve.

Analyze the following code changes and provide a critique. Here's the diff:

$diff_output

And here are the files that were changed:

$changed_files

Please provide an analysis of the changes, including:
1. A summary of what the changes are doing
2. Potential improvements or issues you see
3. Any security concerns
4. Code style and best practices observations

Key instructions:
- Provide your analysis in a clear, concise manner suitable for a PR comment.
- The analysis should be focused on the changes made and its potential impact on the codebase.
- Be referential and give examples for the comments you make.
- Format each section as markdown - so that it can be easily rendered in a PR comment and readable for the user. 
- Special characters like backticks should be escaped.

Your response should be a json in the following format -
{
    \"summary\": {
        \"feedback\": \"Summary of the changes.\",
        \"is_important\": true
    },
    \"improvements\": {
        \"feedback\": \"Potential improvements or issues you see.\",
        \"is_important\": true
    },
    \"security\": {
        \"feedback\": \"Any security concerns.\",
        \"is_important\": true
    },
    \"style\": {
        \"feedback\": \"Code style and best practices observations.\",
        \"is_important\": false
    }
}"

# Function to call AWS using AWS Bedrock
call_aws() {
    local body=$(jq -n \
        --arg prompt "$prompt" \
        '{
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 2000,
            "messages": [
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "text",
                            "text": $prompt
                        }
                    ]
                }
            ]
        }')

    aws bedrock-runtime invoke-model \
        --model-id anthropic.claude-3-sonnet-20240229-v1:0 \
        --body "$body" \
        --cli-binary-format raw-in-base64-out \
        --accept "application/json" \
        --content-type "application/json" \
        "$outfile"

    jq -r '.content[0].text' "$outfile" | sed 's/```json//g' | sed 's/```//g' | jq -r '.'
}

# Function to call Claude using Anthropic API
call_claude() {
    local response=$(curl -s https://api.anthropic.com/v1/messages \
        --header "x-api-key: $ANTHROPIC_API_KEY" \
        --header "anthropic-version: 2023-06-01" \
        --header "content-type: application/json" \
        --data '{
            "model": "claude-3-5-sonnet-20240620",
            "max_tokens": 2000,
            "messages": [
                {
                    "role": "user",
                    "content": '"$(echo "$prompt" | jq -R -s '.')"'
                }
            ]
        }')

    # Extract the content
    local content=$(echo "$response" | jq -r '.content[0].text')

    # Save the content to the file
    echo "$content" > "$outfile"

    # Return the content
    echo "$content"
}

# Function to call GPT-4o using OpenAI API
call_openai() {
    local response=$(curl -s https://api.openai.com/v1/chat/completions \
        -H "Authorization: Bearer $OPENAI_API_KEY" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "gpt-4o",
            "response_format": {"type": "json_object"},
            "messages": [
                {
                    "role": "system",
                    "content": "You are an expert code reviewer who follows the best practices, loves simple and elegant code, and is always looking for ways to improve."
                },
                {
                    "role": "user",
                    "content": '"$(echo "$prompt" | jq -R -s '.')"'
                }
            ]
        }')

    # Extract the content
    local content=$(echo "$response" | jq -r '.choices[0].message.content')

    # Save the content to the file
    echo "$content" > "$outfile"

    # Return the content
    echo "$content"
}

# outfile for temporary storage
outfile="analysis.json"

# Call the appropriate AI model and capture the output
if [ "$AI_MODEL" = "openai" ]; then
    echo "Using GPT-4o (OpenAI) for analysis..."
    analysis=$(call_openai)
elif [ "$AI_MODEL" = "aws" ]; then
    echo "Using Claude (AWS Bedrock) for analysis..."
    analysis=$(call_aws)
else
    echo "Using Claude (Anthropic API) for analysis..."
    analysis=$(call_claude)
fi

# Function to clean and format the JSON
clean_json() {
    local input="$1"
    # Remove leading and trailing whitespace
    local trimmed=$(echo "$input" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    # Check if the input already starts and ends with curly braces
    if [[ "$trimmed" == \{*\} ]]; then
        echo "$trimmed"
    else
        # If not, attempt to extract JSON from the content
        local extracted=$(echo "$trimmed" | sed -n '/^{/,/}$/p')
        if [[ -n "$extracted" ]]; then
            echo "$extracted"
        else
            # If no valid JSON found, return an error JSON
            echo '{"error": "No valid JSON found in the input"}'
        fi
    fi
}

# Function to safely get a value from JSON
safe_get_json_value() {
    local json="$1"
    local key="$2"
    local default="$3"
    local value=$(echo "$json" | jq -r ".$key // \"$default\"" 2>/dev/null)
    if [ $? -ne 0 ] || [ "$value" = "null" ]; then
        echo "$default"
    else
        echo "$value"
    fi
}

# Update the function to add a comment to the PR
add_pr_comment() {
    local title="$1"
    local content="$2"
    local is_important="$3"

    if [ -z "$content" ] || [ "$is_important" = "false" ]; then
        return
    fi
    gh pr comment "$pr_number" --body "## $title

$content"
}

# Parse the analysis and add comments for each important section
parse_and_comment() {
    local analysis="$1"
    local cleaned_json=$(clean_json "$analysis")

    # Check if the cleaned JSON indicates an error
    if [[ $(echo "$cleaned_json" | jq -r '.error // empty') ]]; then
        echo "Error: Failed to parse AI analysis output. Adding error comment to PR."
        gh pr comment "$pr_number" --body "Error: The AI analysis output could not be parsed correctly. Please check the raw output for details."
        return
    fi

    local sections=("summary" "improvements" "security" "style")
    local titles=("Summary" "Potential Improvements" "Security Concerns" "Code Style and Best Practices")

    for i in "${!sections[@]}"; do
        local section="${sections[$i]}"
        local title="${titles[$i]}"
        local feedback=$(safe_get_json_value "$cleaned_json" "$section.feedback" "")
        local is_important=$(safe_get_json_value "$cleaned_json" "$section.is_important" "false")
        add_pr_comment "$title" "$feedback" "$is_important"
    done
}

# Call the parsing and commenting function
parse_and_comment "$analysis"

echo "Analysis added as comments to PR #$pr_number"

# Clean up
# rm -f "$outfile"