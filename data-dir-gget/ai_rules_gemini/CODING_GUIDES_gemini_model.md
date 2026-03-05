# OpenAI compatibility

Gemini models are accessible using the OpenAI libraries (Python and TypeScript / Javascript) along with the REST API, by updating three lines of code and using your [Gemini API key](https://aistudio.google.com/apikey). If you aren't already using the OpenAI libraries, we recommend that you call the [Gemini API directly](https://ai.google.dev/gemini-api/docs/quickstart).

[Python](https://ai.google.dev/gemini-api/docs/openai#python)[JavaScript](https://ai.google.dev/gemini-api/docs/openai#javascript)[REST](https://ai.google.dev/gemini-api/docs/openai#rest)

```
curl"https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"\
-H"Content-Type: application/json"\
-H"Authorization: Bearer $GEMINI_API_KEY"\
-d'{
    "model": "gemini-2.5-flash",
    "messages": [
        {"role": "user", "content": "Explain to me how AI works"}
    ]
    }'
```

What changed? Just three lines!

* **`api_key="GEMINI_API_KEY"`** : Replace "`GEMINI_API_KEY`" with your actual Gemini API key, which you can get in [Google AI Studio](https://aistudio.google.com/).
* **`base_url="https://generativelanguage.googleapis.com/v1beta/openai/"`:** This tells the OpenAI library to send requests to the Gemini API endpoint instead of the default URL.
* **`model="gemini-2.5-flash"`** : Choose a compatible Gemini model

## Thinking

Gemini 2.5 models are trained to think through complex problems, leading to significantly improved reasoning. The Gemini API comes with a [&#34;thinking budget&#34; parameter](https://ai.google.dev/gemini-api/docs/thinking) which gives fine grain control over how much the model will think.

Unlike the Gemini API, the OpenAI API offers three levels of thinking control: "low", "medium", and "high", which behind the scenes we map to 1K, 8K, and 24K thinking token budgets.

If you want to disable thinking, you can set the reasoning effort to "none".

[Python](https://ai.google.dev/gemini-api/docs/openai#python)[JavaScript](https://ai.google.dev/gemini-api/docs/openai#javascript)[REST](https://ai.google.dev/gemini-api/docs/openai#rest)

```
curl"https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"\
-H"Content-Type: application/json"\
-H"Authorization: Bearer $GEMINI_API_KEY"\
-d'{
    "model": "gemini-2.5-flash-preview-04-17",
    "reasoning_effort": "low",
    "messages": [
        {"role": "user", "content": "Explain to me how AI works"}
      ]
    }'
```

## Streaming

The Gemini API supports [streaming responses](https://ai.google.dev/gemini-api/docs/text-generation?lang=python#generate-a-text-stream).

[Python](https://ai.google.dev/gemini-api/docs/openai#python)[JavaScript](https://ai.google.dev/gemini-api/docs/openai#javascript)[REST](https://ai.google.dev/gemini-api/docs/openai#rest)

```
curl"https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"\
-H"Content-Type: application/json"\
-H"Authorization: Bearer $GEMINI_API_KEY"\
-d'{
    "model": "gemini-2.5-flash",
    "messages": [
        {"role": "user", "content": "Explain to me how AI works"}
    ],
    "stream": true
  }'
```

## Function calling

Function calling makes it easier for you to get structured data outputs from generative models and is [supported in the Gemini API](https://ai.google.dev/gemini-api/docs/function-calling/tutorial).

[Python](https://ai.google.dev/gemini-api/docs/openai#python)[JavaScript](https://ai.google.dev/gemini-api/docs/openai#javascript)[REST](https://ai.google.dev/gemini-api/docs/openai#rest)

```
curl"https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"\
-H"Content-Type: application/json"\
-H"Authorization: Bearer $GEMINI_API_KEY"\
-d'{
  "model": "gemini-2.5-flash",
  "messages": [
    {
      "role": "user",
      "content": "What'\''s the weather like in Chicago today?"
    }
  ],
  "tools": [
    {
      "type": "function",
      "function": {
        "name": "get_weather",
        "description": "Get the current weather in a given location",
        "parameters": {
          "type": "object",
          "properties": {
            "location": {
              "type": "string",
              "description": "The city and state, e.g. Chicago, IL"
            },
            "unit": {
              "type": "string",
              "enum": ["celsius", "fahrenheit"]
            }
          },
          "required": ["location"]
        }
      }
    }
  ],
  "tool_choice": "auto"
}'
```

## Image understanding

Gemini models are natively multimodal and provide best in class performance on [many common vision tasks](https://ai.google.dev/gemini-api/docs/vision).

[Python](https://ai.google.dev/gemini-api/docs/openai#python)[JavaScript](https://ai.google.dev/gemini-api/docs/openai#javascript)[REST](https://ai.google.dev/gemini-api/docs/openai#rest)

```
bash-c'
  base64_image=$(base64 -i "Path/to/agi/image.jpeg");
  curl "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $GEMINI_API_KEY" \
    -d "{
      \"model\": \"gemini-2.5-flash\",
      \"messages\": [
        {
          \"role\": \"user\",
          \"content\": [
            { \"type\": \"text\", \"text\": \"What is in this image?\" },
            {
              \"type\": \"image_url\",
              \"image_url\": { \"url\": \"data:image/jpeg;base64,${base64_image}\" }
            }
          ]
        }
      ]
    }"
'
```

## Generate an image

**Note:** Image generation is only available in the paid tier.Generate an image:

[Python](https://ai.google.dev/gemini-api/docs/openai#python)[JavaScript](https://ai.google.dev/gemini-api/docs/openai#javascript)[REST](https://ai.google.dev/gemini-api/docs/openai#rest)

```
curl"https://generativelanguage.googleapis.com/v1beta/openai/images/generations"\
-H"Content-Type: application/json"\
-H"Authorization: Bearer $GEMINI_API_KEY"\
-d'{
        "model": "imagen-3.0-generate-002",
        "prompt": "a portrait of a sheepadoodle wearing a cape",
        "response_format": "b64_json",
        "n": 1,
      }'
```

## Audio understanding

Analyze audio input:

[Python](https://ai.google.dev/gemini-api/docs/openai#python)[JavaScript](https://ai.google.dev/gemini-api/docs/openai#javascript)[REST](https://ai.google.dev/gemini-api/docs/openai#rest)

**Note:** If you get an `Argument list too long` error, the encoding of your audio file might be too long for curl.

```
bash-c'
  base64_audio=$(base64 -i "/path/to/your/audio/file.wav");
  curl "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $GEMINI_API_KEY" \
    -d "{
      \"model\": \"gemini-2.5-flash\",
      \"messages\": [
        {
          \"role\": \"user\",
          \"content\": [
            { \"type\": \"text\", \"text\": \"Transcribe this audio file.\" },
            {
              \"type\": \"input_audio\",
              \"input_audio\": {
                \"data\": \"${base64_audio}\",
                \"format\": \"wav\"
              }
            }
          ]
        }
      ]
    }"
'
```

## Structured output

Gemini models can output JSON objects in any [structure you define](https://ai.google.dev/gemini-api/docs/structured-output).

[Python](https://ai.google.dev/gemini-api/docs/openai#python)[JavaScript](https://ai.google.dev/gemini-api/docs/openai#javascript)

```
frompydanticimport BaseModel
fromopenaiimport OpenAI

client = OpenAI(
    api_key="GEMINI_API_KEY",
    base_url="https://generativelanguage.googleapis.com/v1beta/openai/"
)

classCalendarEvent(BaseModel):
    name: str
    date: str
    participants: list[str]

completion = client.beta.chat.completions.parse(
    model="gemini-2.5-flash",
    messages=[
        {"role": "system", "content": "Extract the event information."},
        {"role": "user", "content": "John and Susan are going to an AI conference on Friday."},
    ],
    response_format=CalendarEvent,
)

print(completion.choices[0].message.parsed)
```

## Embeddings

Text embeddings measure the relatedness of text strings and can be generated using the [Gemini API](https://ai.google.dev/gemini-api/docs/embeddings).

[Python](https://ai.google.dev/gemini-api/docs/openai#python)[JavaScript](https://ai.google.dev/gemini-api/docs/openai#javascript)[REST](https://ai.google.dev/gemini-api/docs/openai#rest)

```
curl"https://generativelanguage.googleapis.com/v1beta/openai/embeddings"\
-H"Content-Type: application/json"\
-H"Authorization: Bearer $GEMINI_API_KEY"\
-d'{
    "input": "Your text string goes here",
    "model": "text-embedding-004"
  }'
```

## List models

Get a list of available Gemini models:

[Python](https://ai.google.dev/gemini-api/docs/openai#python)[JavaScript](https://ai.google.dev/gemini-api/docs/openai#javascript)[REST](https://ai.google.dev/gemini-api/docs/openai#rest)

```
curl "https://generativelanguage.googleapis.com/v1beta/openai/models"\
-H"Authorization: Bearer $GEMINI_API_KEY"
```

## Retrieve a model

Retrieve a Gemini model:

[Python](https://ai.google.dev/gemini-api/docs/openai#python)[JavaScript](https://ai.google.dev/gemini-api/docs/openai#javascript)[REST](https://ai.google.dev/gemini-api/docs/openai#rest)

```
curl "https://generativelanguage.googleapis.com/v1beta/openai/models/gemini-2.5-flash"\
-H"Authorization: Bearer $GEMINI_API_KEY"
```
