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
- Be referential and give examples for the comments you make.
- Format each section as markdown - so that it can be easily rendered in a PR comment and readable for the user. 
- Special characters like backticks should be escaped.

Your response should be a json in the following format -
{
    \"summary\": \"Summary of the changes.\",
    \"improvements\": \"Potential improvements or issues you see.\",
    \"security\": \"Any security concerns.\",
    \"style\": \"Code style and best practices observations.\"
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
    local content=$(echo "$response" | jq -r '.content[0].text' | sed 's/[\x00-\x1F\x7F]//g')

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

# Function to add a comment to the PR
add_pr_comment() {
    local title="$1"
    local content="$2"

    if [ -z "$content" ]; then
        return
    fi
    gh pr comment "$pr_number" --body "## $title

$content"
}

# Add comments for each section of the analysis
add_pr_comment "Summary" "$(echo "$analysis" | jq -r '.summary')"
add_pr_comment "Potential Improvements" "$(echo "$analysis" | jq -r '.improvements')"
add_pr_comment "Security Concerns" "$(echo "$analysis" | jq -r '.security')"
add_pr_comment "Code Style and Best Practices" "$(echo "$analysis" | jq -r '.style')"
echo "Analysis added as comments to PR #$pr_number"

# Clean up
# rm -f "$outfile"
