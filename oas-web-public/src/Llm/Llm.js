import { useEffect, useRef, useState, useCallback, memo } from "react";
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
import { map, last, first, union, unionBy, reverse, some, find } from "lodash"

// import getWasm from "shiki/wasm";

import {
  codeBlockLookBack,
  findCompleteCodeBlock,
  findPartialCodeBlock,
} from "@llm-ui/code";
import { markdownLookBack } from "@llm-ui/markdown";
import { useLLMOutput, useStreamExample, throttleBasic } from "@llm-ui/react";
import { Form, useNavigate, useParams } from "react-router-dom";
import { FormControl, TextField, Button, Box, Switch } from "@mui/material";
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
  }, [id])


  return <>
    {id && < Llm />}
    {!id && <div>Id required</div>}
  </>
}

const isMe = (message, who_am_i) => {
  return message.metadata?.member?.id !== undefined &&
    message.metadata?.member?.id === who_am_i.id
    && message.role === "user"
}

export const mergePresenceParticipants = (presence, participants) => {
  const presenceMembers = presence.map((pres) => {
    return {
      ...first(pres.metas).member,
      llm: some(pres.metas, ({llm}) => llm),
      online: true
    }
  })
  return unionBy(presenceMembers, participants, ({ id }) => id)
}

export const Llm = () => {

  const [channel, setChannel] = useState(undefined);
  const [prompt, setPrompt] = useState("")
  const [messages, setMessages] = useState([])
  const [output, setOutput] = useState("")
  const [isStreamFinished, setIsStreamFinished] = useState(true)
  const [whoIdObj, setWhoIdObj] = useState({})
  const [presenceState, setPresenceState] = useState([])
  const [participants, setParticipants] = useState([])

  const { id } = useParams()


  const pushMessage = useCallback((message) => {
    setMessages((messages ) => [{
      content: [ {
        type: "text",
        content: message.content
      } ],
      role: message.role,
      metadata: message.metadata,
      isMe: message.metadata?.member?.presence_id && message.metadata.member.presence_id === whoIdObj.presence_id
    }, ...messages])
  }, [setMessages, whoIdObj])

  useEffect(() => {
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
      if (message.content.length === 0) {
        // Probably a tool call
        return;
      }
      setMessages((messages) => {
        // console.log("===============================")
        // console.log("on message ----", message.message_index)
        // console.log("001 messages length", messages.length)
        // console.log("002 message", message)

        let index = messages.length - message.message_index - 1;
        let step = 1;
        if (index < 0) {
          index = 0;
          step = 1;
        }
        const out = messages.toSpliced(
          index,
          step,
          message)
        return out
      })
    })
    channel.on("messages", ({messages, who_am_i}) => {
      setWhoIdObj(who_am_i)
      setMessages(
        messages.map((message) => {
          return {
            ...message,
            ...(isMe(message, who_am_i) ? { isMe: true } : {})
          }
        })
      )
    })
    channel.on("participants", ({participants}) => {
      setParticipants(participants)
    })
    // from other clients
    channel.on("prompt", (prompt) => {
      setMessages((messages ) => [prompt, ...messages])
    })

    presence.onSync(() => {
      setPresenceState(Object.entries(presence.state).map(([k, v]) => { return {id: k, metas: v.metas} }))
    })

    channel
      .join()
      .receive("ok", (resp) => {
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
    // llmOutput: "Test content",
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

  const presenceParticipants = mergePresenceParticipants(presenceState, participants);

  // console.log("000", presenceState)
  // console.log("001", presenceParticipants)
  // console.log("002", whoIdObj)

  return (
    <div className="chat-content">
      <ul className="presence-participants">
        {some(presenceParticipants, ({llm}) => llm) && <li>
          <span >assistent</span>&nbsp;
          <span className="online"></span>
          {<Switch
            checked={true}
            disabled={!(find(presenceParticipants, ({llm}) => llm).presence_id === whoIdObj.presence_id || whoIdObj.is_admin)}
            onChange={ (event) => {
              channel.push("toggle_llm", {
                presence_id: find(presenceParticipants, ({llm}) => llm).presence_id,
                value: false
              })
            } } />}
          {/* {(i < (presenceParticipants).length - 1) && <span>, &nbsp;</span>}*/}
        </li>}
        {(presenceParticipants).map((who, i) => {
          return <li key={i}>
            <span >{ who.name || who.id || "anonymous" }</span>&nbsp;
            {who.online ? <span className="online"></span> : <span className="offline"></span>}
            {<Switch
              checked={who.llm || false}
              disabled={!(who.presence_id === whoIdObj.presence_id || whoIdObj.is_admin)}
              onChange={ (event) => {
                channel.push("toggle_llm", {
                  presence_id: who.presence_id,
                  value: event.target.checked
                })
              } } />}
            {/* {(i < (presenceParticipants).length - 1) && <span>, &nbsp;</span>}*/}
          </li>
        })}
      </ul>
      <div className="messages">
        <div>
          {(blockMatches.length > 0 /* || true /* DEBUG ONLY */) && <div style={{marginRight: "20%"}}>
            <div className="llm-content">
              {blockMatches.map((blockMatch, index) => {
                const Component = blockMatch.block.component;
                return <Component key={index} blockMatch={blockMatch} />;
              })}
            </div>
            <div style={{ textAlign: "right" }}>assistant</div>
          </div>}
        </div>
        { messages.map(((message, index) => {
          return <ContentBox key={index} message={message} presenceState={presenceState} />
        }))}
      </div>
      <Box className="chat-input" sx={{display: 'flex', alignItems: 'center'}}>
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
