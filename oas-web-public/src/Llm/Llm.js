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
// import { bundledThemes } from "shiki/themes";
import parseHtml from "html-react-parser";
import { getHighlighterCore } from "shiki/core";
import { bundledLanguagesInfo } from "shiki/langs";
import { map, last } from "lodash"

// import getWasm from "shiki/wasm";

import {
  codeBlockLookBack,
  findCompleteCodeBlock,
  findPartialCodeBlock,
} from "@llm-ui/code";
import { markdownLookBack } from "@llm-ui/markdown";
import { useLLMOutput, useStreamExample, throttleBasic } from "@llm-ui/react";
import { Form, useNavigate, useParams } from "react-router-dom";
import { FormControl, TextField, Button, Box } from "@mui/material";
import Cookies from "js-cookie";
import { Socket as PhoenixSocket, Presence } from "phoenix";
import { v4 } from 'uuid'
import { MarkdownComponent, CodeBlock, ContentBox, LLMOutputOpitons } from "./ContentBox";

export const PreLlm = () => {
  const navigate = useNavigate()
  const { id } = useParams()

  useEffect(() => {
    if (!id) {
      navigate(`/llm/${v4()}`)
      return
    }
  }, [])


  return <>
    {id && < Llm />}
    {!id && <div>Id required</div>}
  </>
}

export const Llm = () => {
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
  const [presenceState, setPresenceState] = useState([])

  const { id } = useParams()


  const pushMessage = useCallback((message) => {
    setMessages((messages ) => [...messages, {
      content: [ {
        type: "text",
        content: message.content
      } ],
      role: message.role,
      metadata: message.metadata,
      isMe: message.metadata?.member?.presence_id && message.metadata.member.presence_id === whoIdObj.presence_id
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

    let channel = phoenixSocket.channel(`llm:${id}`, {})
    let presence = new Presence(channel)

    let messages = [];
    let accData = "";
    channel.on("delta", (data) => {
      // console.log("001 delta", data)
      if (data.content) {
        accData = accData + data.content
      }
      setIsStreamFinished(data.done)
      if (data.status === "complete") {
        pushMessage({
          role: "assistent",
          content: accData
        })
        accData = ""
      }
      setOutput(accData)
    })
    channel.on("message", (message) => {
      setMessages((messages) => {
        return messages.toSpliced(message.message_index, 1, message)
      })
    })
    channel.on("messages", ({messages, who_am_i}) => {
      setWhoIdObj(who_am_i)
      setMessages(
        messages.map((message) => {
          return {
            ...message,
            ...(message.metadata?.member?.id === who_am_i.id ? { isMe: true } : {})
          }
        })
      )
    })
    channel.on("state", (state) => {
    })
    // from other clients
    channel.on("prompt", (prompt) => {
      setMessages((messages ) => [...messages, prompt])
      // pushMessage(prompt)
    })

    presence.onSync(() => {
      setPresenceState(Object.entries(presence.state).map(([k, v]) => { return {id: k, metas: v.metas} }))
    })

    channel
      .join()
      .receive("ok", (resp) => {
        // Find out who I am
        // channel.push("who_am_i")
        //   .receive("ok", (payload) => {
        //     console.log("001 set_who_am_i")
        //     setWhoIdObj(payload)
        //   })
        //   .receive("error", (error) => {
        //     console.error("error", error)
        //   })
        //   .receive("timeout", (timeout) => {
        //     console.error("timeout", timeout)
        //   })
      })
      .receive("error", (resp) => {
        console.error("error", resp)
      })
    setChannel(channel)


    return () => {
      setChannel(undefined)
      channel.leave()
      phoenixSocket.disconnect(() => {
        console.warn("003 phoenixSocket disconnect")
      });
    }
  }, [])

  const { blockMatches } = useLLMOutput({
    llmOutput: output,
    ...LLMOutputOpitons
  });

  const user_prompt = (prompt, member) => {
    pushMessage({
      content: prompt,
      role: "user",
      metadata: {
        member: member
      }
      // metas: [
      //   {
      //     member: whoIdObj
      //   }
      // ]
    })
    channel.push("prompt", prompt)
    setPrompt("")
  }

  return (
    <div>
      <div>
        {(presenceState).map((who, i) => {
          return <span key={i}>
            <span >{ last(who.metas)?.member?.name || who.id }</span>
            {(i < (presenceState).length - 1) && <span>, &nbsp;</span>}
          </span>
        })}
      </div>
      <div>
        {messages.map((message, index) => {
          return <ContentBox key={index} message={message} presenceState={presenceState} />
        })}
        {(blockMatches.length > 0) && <div className="llm-content">
          {blockMatches.map((blockMatch, index) => {
            const Component = blockMatch.block.component;
            return <Component key={index} blockMatch={blockMatch} />;
          })}
        </div>}
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
              user_prompt(prompt, whoIdObj)
            }}>Submit</Button>
        </FormControl>
      </Box>
    </div>
  );
}
