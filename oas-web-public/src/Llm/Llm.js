import { useEffect, useRef, useState, useCallback, memo } from "react";
import { map, last, first, union, unionBy, reverse, some, find, findIndex, throttle, startsWith, get, isEqual } from "lodash"
import { useLLMOutput, useStreamExample, throttleBasic } from "@llm-ui/react";
import { Form, useNavigate, useOutletContext, useParams } from "react-router-dom";
import { FormControl, TextField, Button, Box, Switch } from "@mui/material";
import Cookies from "js-cookie";
import { Socket as PhoenixSocket, Presence } from "phoenix";
import { v4 } from 'uuid'
import { MarkdownComponent, CodeBlock, ContentBox, LLMOutputOpitons } from "./ContentBox";
import { useQuery, gql} from '@apollo/client'

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
    message.metadata?.member?.id === who_am_i.member?.id
    && message.role === "user"
}

export const mergePresenceParticipants = (presence, participants) => {
  // console.log("005", participants)
  // TODO: change first to find the actuall relevent meta.
  const presenceMembers = presence.map((pres) => {
    return {
      ...(first(pres.metas).member ?
        {id : first(pres.metas).member.id} : {id: pres.presence_id}
      ), // For the merge
      presence_id: pres.presence_id,
      member: first(pres.metas).member,
      // llm: some(pres.metas, ({llm}) => llm),
      presence_name: first(pres.metas).presence_name,
      online: true,
      channel_pid: first(pres.metas).channel_pid,
      from_channel_pid: first(pres.metas).from_channel_pid
    }
  })
  const out = unionBy(presenceMembers, participants, ({ id }) => id)
  // console.log("006", out)
  return out;
}

export const Llm = () => {

  const [channel, setChannel] = useState(undefined);
  const [prompt, setPrompt] = useState("")
  const [messages, setMessages] = useState([])
  const [output, setOutput] = useState("")
  const [outputKey, setOutputKey] = useState(v4())
  const [isStreamFinished, setIsStreamFinished] = useState(true)
  const [whoIdObj, setWhoIdObj] = useState({})
  const [presenceState, setPresenceState] = useState([])
  const [participants, setParticipants] = useState([])
  const [disableInput, setDisableInput] = useState(false)
  const [outletContext] = useOutletContext()

  const { id } = useParams()

  const { data: configData } = useQuery(gql`
    query {
      public_config_llm {
        llm_enabled,
        llm_enabled
      }
    }
  `)

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
    let channel
    (async () => {
      const phoenixSocket = await outletContext.phoenixSocketPromise
      channel = phoenixSocket.channel(`llm:${id}`, {})
      let presence = new Presence(channel)

      let accData = "";
      channel.on("delta", (data) => {
        if (data.content) {
          accData = accData + data.content
        }
        setIsStreamFinished(data.done)
        if (data.status === "complete") {
          pushMessage({
            role: "assistent",
            content: accData,
            metadata: data.metadata
          })
          setDisableInput(false);
          accData = ""
        }
        // setOutputKey(v4())
        setOutput(accData)
      })

      channel.on("message", (message) => {
        setDisableInput(false)
        if (message.content?.length === 0) {
          // Probably a tool call
          return;
        }
        setMessages((messages) => {
          const index = findIndex(messages, (mess) => mess.metadata.index === message.metadata.index)
          let out;
          if (message.metadata.index === undefined || index === -1) {

            out = [message, ...messages]
          } else {
            out = messages
          }

          return out
        })
      })
      channel.on("messages", ({messages, who_am_i, participants}) => {
        // console.log("002.1 messages WAT", messages)
        // console.log("002.2 who_am_i", who_am_i)
        // console.log("002.3 participants", participants)
        setWhoIdObj(who_am_i)
        setParticipants(participants)
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
        setPresenceState(Object.entries(presence.state).map(([k, v]) => { return {presence_id: k, metas: v.metas} }))
      })

      channel
        .join()
        .receive("ok", (resp) => {
        })
        .receive("error", (resp) => {
          console.error("error", resp)
        })
      setChannel(channel)
    })()


    return () => {
      setChannel(undefined)
      channel && channel.leave()
      // phoenixSocket.disconnect(() => {
      //   console.warn("003 phoenixSocket disconnect")
      // });
    }
  }, [id])

  useEffect(() => {
    const meIndex = findIndex(participants, (participant) => participant.id == whoIdObj.presence_id)
    if (meIndex > 0) {

      const newParticipants = [
        participants[meIndex],               // The 'Me' user first
        ...participants.slice(0, meIndex),   // Everyone before 'Me'
        ...participants.slice(meIndex + 1)   // Everyone after 'Me'
      ]
      setParticipants(newParticipants);
    }

  }, [participants, whoIdObj])

  const { blockMatches } = useLLMOutput({
    llmOutput: output,
    // llmOutput: "Test content",
    ...LLMOutputOpitons
  });

  const user_prompt = (prompt, member) => {
    if (disableInput) {
      return;
    }
    pushMessage({
      content: prompt,
      role: "user",
      metadata: {
        member: member,
        presence_name: whoIdObj.presence_name
      }
    })
    if (find(presenceParticipants, ({presence_id, llm}) =>  presence_id === whoIdObj.presence_id && llm)) {
      setDisableInput(true);
    }
    channel.push("prompt", prompt)
    setPrompt("")
  }


  let presenceParticipants = mergePresenceParticipants(presenceState, participants);

  const meIndex = findIndex(presenceParticipants, (participant) => participant.id == whoIdObj.presence_id)
  if (meIndex > 0) {
    presenceParticipants = [
      presenceParticipants[meIndex],               // The 'Me' user first
      ...presenceParticipants.slice(0, meIndex),   // Everyone before 'Me'
      ...presenceParticipants.slice(meIndex + 1)   // Everyone after 'Me'
    ]
  }

  // console.log("101, presenceState", presenceState)
  // console.log("102, presenecParticipants", presenceParticipants)

  return (
    <div className="chat-content">
      <ul className="presence-participants">
        {(presenceParticipants).map((who, i) => {
          return <li key={i}>
            <span >{ who.presence_name ||who.name || who.presence_id || "unknown" }</span>&nbsp;
            {who.online ? <span className="online"></span> : <span className="offline"></span>}
            {!startsWith(who.presence_id, "assistent") && get(configData, "public_config_llm.llm_enabled", false) && <Switch
              checked={some(presenceState, ({metas}) => {
                const out = some(metas, ({from_channel_pid}) => from_channel_pid === who.channel_pid)
                return out
              }) || false}
              disabled={
                who.presence_id === undefined || // They're not in the room
                !(who.presence_id === whoIdObj.presence_id || who.from_channel_pid === whoIdObj.channel_pid || whoIdObj.member?.is_admin)
              }
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
          {(blockMatches.length > 0 /* || true /* DEBUG ONLY */) && <div className="delta-message" style={{marginRight: "20%"}}>
            <div className="llm-content">
              {blockMatches.map((blockMatch, index) => {
                const Component = blockMatch.block.component;
                return <Component key={`${index}-${blockMatches.length}-${outputKey}`} blockMatch={blockMatch} />;
              })}
            </div>
            <div style={{ textAlign: "right" }}>assistant</div>
          </div>}
        </div>
        { messages.map(((message, index) => {
          return <ContentBox key={`${index}-${messages.length}-ms`} message={message} presenceState={presenceState} />
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
            disabled={!channel || channel.state !== "joined" || disableInput}
            onClick={() => {
              user_prompt(prompt, whoIdObj)
            }}>Submit</Button>
        </FormControl>
      </Box>
    </div>
  );
}
