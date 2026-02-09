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
  const [channel, setChannel] = useState(undefined);
  const [history, setHistory] = useState([]);
  const [presence, setPresence] = useState({});
  const [outletContext] = useOutletContext();

  useEffect(() => {
    let channel;
    (async () => {
      const phoenixSocket = await outletContext.phoenixSocketPromise
      channel = phoenixSocket.channel(`history`, {})
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
    })()

    return () => {
      setChannel(undefined)
      channel && channel.leave()
    }
  }, [])

  const mergeHistoryAndPresence = (history, presence) => {
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
            return <LlmHistoryRow key={i} history={history} phoenixSocket={outletContext.phoenixSocket} />
          })}
        </TableBody>
      </Table>
    </TableContainer>
  </Box>
}
