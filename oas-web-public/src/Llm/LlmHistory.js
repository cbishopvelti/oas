import { useEffect, useRef, useState, useCallback, memo } from "react";
import Cookies from "js-cookie";
import { Socket as PhoenixSocket, Presence } from "phoenix";
import { Table, TableContainer, Box, TableHead, TableRow, TableCell, TableBody, Alert, Button } from "@mui/material";
import { Link } from "react-router-dom";
import { findIndex, map, pickBy, get } from 'lodash';
import { mergePresenceParticipants } from "./Llm";
import { useOutletContext } from 'react-router-dom'

const LlmHistoryRow = ({
  history,
  phoenixSocket
}) => {
  useEffect(() => {
    // let channel = phoenixSocket.channel(history.topic, {})
    // const presence = new Presence(channel)

    // presence.onSync(() => {
    //   console.log("405 onSync", presence)
    // })

    // channel.join()

  }, [phoenixSocket])


  const presenceArray = Object.entries(history.presence || {}).map(([k, v]) => { return {id: k, metas: v.metas} })
  const presenceParticipants = mergePresenceParticipants(
    presenceArray,
    (history?.members || []).map((member) => {
      return member
    })
  )

  return <TableRow>
    <TableCell>{ history.id }</TableCell>
    <TableCell>{ history.topic }</TableCell>
    <TableCell><ul className="history-participants">{presenceParticipants.map((member, i) => {
      return <li key={i}>
        <span>{ member.presence_name || member.name }</span>
        {member.online ? <span className="online"></span> : <span className="offline"></span>}
      </li>
    }) }</ul></TableCell>
    <TableCell>
      {/* <Link styleName={`btn`} style={{width: '100%'}} to={ `/llm/${history.topic.replace("llm:", "")}` } >Join</Link>*/}
      <Button
        to={`/llm/${history.topic.replace("llm:", "")}`}
        component={Link}
        color="success"
        sx={{width: '100%'}}
        >Join</Button>
    </TableCell>
  </TableRow>
}

export const LlmHistory = () => {
  const [phoenixSocket, setPhoenixSocket] = useState(undefined);
  const [channel, setChannel] = useState(undefined);
  const [history, setHistory] = useState([]);
  const [presence, setPresence] = useState({});
  const [outletContext] = useOutletContext();

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
    setPhoenixSocket(phoenixSocket)

    let channel = phoenixSocket.channel(`history`, {})
    const presence = new Presence(channel)

    channel.on("history", ({history}) => {
      setHistory(history);
    })
    channel.on("new_history", (new_history) => {
      setHistory((history) => {
        const index = findIndex(history, ({id}) => id === new_history.id)

        return [
          new_history,
          ...(index !== -1 ? history.toSpliced(index, 1 ) : history)
        ]
      })
    })

    presence.onSync(() => {
      console.log("001 onSync ------", presence)
      setPresence({
        ...presence.state
      })
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

  const mergeHistoryAndPresence = (history, presence) => {
    // console.log("601 mergeHistoryAndPresence")
    // console.log("601.1 history", history)
    // console.log("601.2 presence", presence)
    return map(history, (histor) => {
      const presenceForHistory = pickBy(presence, (presenc) => {
        return presenc.topic === histor.topic
      })
      return {
        ...histor,
        presence: presenceForHistory
      }
    })
  }

  // console.log("----------------------------")
  const historyAndPresence = mergeHistoryAndPresence(history, presence)

  return <Box>
    {!get(outletContext, "user") && <Alert severity="warning">You must be <a
      href={`${process.env.REACT_APP_SERVER_URL}/members/log_in`}>
        Logged in
    </a> to view your history.</Alert>}
    <TableContainer>
      <Table>
        <TableHead>
          <TableRow>
            <TableCell>id</TableCell>
            <TableCell>topic</TableCell>
            <TableCell>participants</TableCell>
            <TableCell>actions</TableCell>
          </TableRow>
        </TableHead>
        <TableBody>
          {historyAndPresence.map((history, i) => {
            return <LlmHistoryRow key={i} history={history} phoenixSocket={phoenixSocket} />
          })}
        </TableBody>
      </Table>
    </TableContainer>
  </Box>
}
