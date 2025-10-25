import { useEffect, useRef, useState, useCallback } from "react";
import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";
import {
  loadHighlighter,
  useCodeBlockToHtml,
  allLangs,
  allLangsAlias,
} from "@llm-ui/code";
// WARNING: Importing bundledThemes increases your bundle size
// see: https://llm-ui.com/docs/blocks/code#bundle-size
import { bundledThemes } from "shiki/themes";
import parseHtml from "html-react-parser";
import { getHighlighterCore } from "shiki/core";
import { bundledLanguagesInfo } from "shiki/langs";

import getWasm from "shiki/wasm";

import {
  codeBlockLookBack,
  findCompleteCodeBlock,
  findPartialCodeBlock,
} from "@llm-ui/code";
import { markdownLookBack } from "@llm-ui/markdown";
import { useLLMOutput, useStreamExample, throttleBasic } from "@llm-ui/react";
import { Form } from "react-router-dom";
import { FormControl, TextField, Button, Box } from "@mui/material";
import Cookies from "js-cookie";
import { Socket as PhoenixSocket } from "phoenix";
import { v4 } from 'uuid'
import { MarkdownComponent, CodeBlock, ContentBox } from "./ContentBox";


const example = `## Python

\`\`\`python
print('Hello llm-ui!')
\`\`\`
...continues...
`;


export const Llm = ({ blockMatch }) => {
  // const { isStreamFinished, output } = useStreamExample(example, {
  //   autoStart: true,
  //   autoStartDelayMs: 0,
  //   startIndex: 0,
  //   delayMultiplier: 0
  // });

  const [channel, setChannel] = useState(undefined);
  const [prompt, setPrompt] = useState("")
  const [messages, setMessages] = useState([])
  const [output, setOutput] = useState("")
  const [isStreamFinished, setIsStreamFinished] = useState(true)
  const [whoIdObj, setWhoIdObj] = useState({})

  const pushMessage = useCallback((message) => {
    console.log("006", message.content, whoIdObj, message.who_id_str === whoIdObj.who_id_str)
    setMessages((messages ) => [...messages, {
      ...message,
      isMe: message.who_id_str && message.who_id_str === whoIdObj.who_id_str
    }])
  }, [setMessages, whoIdObj])

  useEffect(() => {
    // console.log("002", `${process.env["REACT_APP_SERVER_URL"].replace(/^http/, "ws")}/public_socket`)
    const phoenixSocket = new PhoenixSocket(`${process.env["REACT_APP_SERVER_URL"].replace(/^http/, "ws")}/public_socket`, {
      reconnectAfterMs: (() => 120_000),
     	rejoinAfterMs: (() => 120_000),
      params: () => {
        if (Cookies.get("oas_key")) {
          return { cookie: Cookies.get("oas_key") };
        } else {
          return {};
        }
      }
    });
    phoenixSocket.connect()
    // console.log("001 pheonixSocket", phoenixSocket);

    let channel = phoenixSocket.channel(`llm:${v4()}`, {})

    // channel.on("echo", (echo) => {
    //   console.log("echo", echo)
    // })
    let messages = [];
    let accData = "";
    channel.on("data", (data) => {
      // console.log("001 data", data)
      accData = accData + data.message.content
      setIsStreamFinished(data.done)
      if (data.done) {
        pushMessage({
          role: "assistent",
          content: accData
        })
        accData = ""
      }
      setOutput(accData)
    })

    channel
      .join()
      .receive("ok", (resp) => {
        console.log("ok SHOULD HAPPEN", resp)
        // Find out who I am
        channel.push("who_am_i")
          .receive("ok", (payload) => {
            console.log("008 setWhoIdObj")
            setWhoIdObj(payload)
          })
          .receive("error", (error) => {
            console.error("error", error)
          })
          .receive("timeout", (timeout) => {
            console.error("timeout", timeout)
          })
      })
      .receive("error", (resp) => {
        console.error("error", resp)
      })
    setChannel(channel)


    return () => {
      setChannel(undefined)
      channel.leave()
      phoenixSocket.disconnect(() => {
        console.log("003 phoenixSocket disconnect")
      });
    }
  }, [])

  const { blockMatches } = useLLMOutput({
    llmOutput: output,
    fallbackBlock: {
      component: MarkdownComponent,
      lookBack: markdownLookBack(),
    },
    blocks: [
      {
        component: CodeBlock,
        findCompleteMatch: findCompleteCodeBlock(),
        findPartialMatch: findPartialCodeBlock(),
        lookBack: codeBlockLookBack(),
      },
    ],
    isStreamFinished,
    throttle: throttleBasic({
      readAheadChars: 1,
      targetBufferChars: 1,
      adjustPercentage: 1,
      frameLookBackMs: 20,
      windowLookBackMs: 0,
    })
  });

  const user_prompt = (prompt, whoIdObj) => {
    pushMessage({
      content: prompt,
      role: "user",
      who_id_str: whoIdObj.who_id_str
    })
    channel.push("prompt", prompt)
  }

  console.log("010 whoIdObj", whoIdObj)
  return (
    <div>
      <div>
        {messages.map((message, index) => {
          return <ContentBox key={index} message={message} />
        })}
        <div>
          {blockMatches.map((blockMatch, index) => {
            const Component = blockMatch.block.component;
            return <Component key={index} blockMatch={blockMatch} />;
          })}
        </div>
      </div>
      <Box sx={{display: 'flex', alignItems: 'center'}}>
        <FormControl sx={{flexGrow: 5}}>
          <TextField
            id="prompt"
            label="Prompt"
            value={prompt}
            onChange={(event) => { setPrompt(event.target.value) }}
            onKeyUp={(event) => {
              if (event.key === 'Enter') {
                console.log("011", whoIdObj)
                // channel.push("prompt", prompt)
                user_prompt(prompt, whoIdObj)
              }
            }}
            error={false}
            helperText={""}
          />
        </FormControl>
        <FormControl>
          <Button
            disabled={!channel || channel.state !== "joined"}
            onClick={() => {
              console.log("011", whoIdObj)
              user_prompt(prompt, whoIdObj)
            }}>Submit</Button>
        </FormControl>
      </Box>
    </div>
  );
}
