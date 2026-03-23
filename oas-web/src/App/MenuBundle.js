import { MenuItem, ListItemText, IconButton, Collapse } from "@mui/material"
import KeyboardArrowDownIcon from '@mui/icons-material/KeyboardArrowDown';
import KeyboardArrowUpIcon from '@mui/icons-material/KeyboardArrowUp';
import { CustomLink } from "./Links"
import { useMatches, NavLink } from "react-router-dom";
import { useState, useEffect } from "react";
import { some, includes } from "lodash";


export const MenuBundle = () => {

  const matches = useMatches();

  const pricing = ["pricing", "pricing-id"]
  const pricingIntsance = ["pricing-instance", "pricing-instance-id"]
  const allIds = [...pricing, ...pricingIntsance];

  const forceActive = some(matches, ({ id }) => includes(allIds, id));
  const active = some(matches, ({ id }) => includes(allIds, id));
  const [open, setOpen] = useState(active);

  useEffect(() => {
    if (!active) {
      setOpen(false);
    } else if (active) {
      setOpen(true);
    }
  }, [matches]);

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
      component={CustomLink(allIds)} end to={`/pricing_instances`}>
      <ListItemText>Bundles</ListItemText>
      <IconButton onClick={handleOpen}>
        {
          open ? <KeyboardArrowUpIcon /> : <KeyboardArrowDownIcon />
        }
      </IconButton>
    </MenuItem>
    <Collapse in={open} timeout="auto">
      <MenuItem
        sx={{ml:2}}
        component={CustomLink([ "pricing-id"])}
        to={`/pricings`}
        end
        >
          <ListItemText>Pricings</ListItemText>
      </MenuItem>
      <MenuItem
        sx={{ml:2}}
        component={NavLink}
        to={`/pricing`}
        end
        >
          <ListItemText>New Pricing</ListItemText>
      </MenuItem>

      <MenuItem
        sx={{ml: 2}}
        component={CustomLink(["pricing-instance-id"])}
        to={`/pricing-instances`}
        end>
          <ListItemText>Pricing Instances</ListItemText>
      </MenuItem>
      <MenuItem
        sx={{ml: 2}}
        component={NavLink}
        to={"/pricing-instance"}
        end
        >
        <ListItemText>New Pricing Instance</ListItemText>
      </MenuItem>

    </Collapse>
  </>

}
