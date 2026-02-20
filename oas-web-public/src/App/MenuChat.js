import { MenuList, MenuItem, Divider, ListItem, ListItemText, Collapse, IconButton } from '@mui/material';
import {
  NavLink,
  useMatch,
  useMatches,
  useOutletContext
} from "react-router-dom";
import { CustomLink } from './Links';
import KeyboardArrowDownIcon from '@mui/icons-material/KeyboardArrowDown';
import KeyboardArrowUpIcon from '@mui/icons-material/KeyboardArrowUp';
import { find, findIndex, includes, some, uniqBy } from 'lodash';
import { useEffect, useState } from 'react';
import Cookies from "js-cookie";
import { Socket as PhoenixSocket, Presence } from "phoenix";
import { usePrevious } from './utils';

export const MenuChat = ({
  phoenixSocketResolve,
  phoenixSocketReject
}) => {

  const matches = useMatches();
  const prevMatches = usePrevious(matches)

  const menuIds = ["llm", "llm-id"];
  const subMenuIds = ['llm-history'];
  const allIds = [...menuIds, ...subMenuIds];
  const forceIds = [...subMenuIds];

  const [unreadMessages, setUnreadMessages] = useState([])
  const active = some(matches, ({ id }) => includes(allIds, id));
  const forceActive = some(matches, ({id}) => includes(forceIds, id));
  const [open, setOpen] = useState(active);

  // const [phoenixSocket, setPhoenixSocket] = useState(undefined);


  useEffect(() => {
    let isActive = true;

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

    phoenixSocket.onError(() => {
      if (!isActive) return;
      phoenixSocketReject(new Error("Failed to open socket"))
    })
    phoenixSocket.onOpen(() => {
      if (!isActive) return;
      console.log("phoenixSocket onOpen")
      phoenixSocketResolve(phoenixSocket)
    })

    let channel = phoenixSocket.channel(`global`, {})
    channel.on("new_message", (data) => {
      setUnreadMessages((unreadMessages) => {
        return uniqBy([data, ...unreadMessages], ({topic}) => topic)
      })
      setOpen(true)
    })
    channel.on("new_messages", ({new_messages}) => {
      setUnreadMessages(new_messages)
      if (new_messages.length > 0) setOpen(true)
    })

    channel
      .join()
      .receive("ok", (resp) => {
      })
      .receive("error", (resp) => {
        console.error("error", resp)
      })

    return () => {
      isActive = false;
      phoenixSocket.disconnect(() => {
        console.warn("003 phoenixSocket disconnect")
      });
    }
  }, [])

  useEffect(() => {
    if (matches === prevMatches) { // Same route, do nothing
      return
    }

    const match = find(prevMatches, ({ id }) => id === 'llm-id')

    if (match) {
      const { params: { id: my_topic_id } } = match

      setUnreadMessages((unreadMessages) => {
        const index = findIndex(unreadMessages, (unread_mess) => {
          return unread_mess.topic.replace("llm:", "") === my_topic_id
        } )
        if (index > -1) {
          return unreadMessages.toSpliced(index, 1);
        }
        return unreadMessages
      })

    }

  }, [matches, prevMatches])

  useEffect(() => {
    if (!forceActive && !active) {
      setOpen(false);
    } else if (forceActive) {
      setOpen(true);
    }
  }, matches);

  const handleOpen = (event) => {
    event.stopPropagation();
    event.preventDefault();

    if (forceActive) {
      return;
    }

    setOpen(!open)

    return false;
  }

  return <>
    <MenuItem
      component={CustomLink(menuIds)} end to={`/llm`}>
      <ListItemText>Chat</ListItemText>
      <IconButton onClick={handleOpen}>
        {
          open ? <KeyboardArrowUpIcon /> : <KeyboardArrowDownIcon />
        }
      </IconButton>
    </MenuItem>
    <Collapse in={open} timeout="auto">
      {
        unreadMessages.map((item, i) => {
          const active = some(matches, ({ id, params: {id: chat_id} }) => {
            return id === "llm-id" && chat_id === item.topic.replace("llm:", "")
          })

          return <MenuItem
            key={i}
            sx={{ml:2}}
            component={NavLink}
            to={`/llm/${item.topic.replace("llm:", "")}`}
            end
            >
            <ListItemText>{item.presence_name}</ListItemText>
            {!active && <span className="unread" title={"Unread messages"}></span>}
          </MenuItem>
        })
      }
      <MenuItem
        sx={{ml:2}}
        component={NavLink}
        to={`/llm-history`}
        end
        >
        <ListItemText>History</ListItemText>
      </MenuItem>
    </Collapse>
  </>
}
