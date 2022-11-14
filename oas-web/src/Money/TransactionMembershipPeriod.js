import { useState, useEffect } from "react"
import { FormControl, FormControlLabel, Switch, InputLabel, Select, MenuItem } from "@mui/material"
import { get, omit } from "lodash"
import { useQuery, gql } from "@apollo/client"



export const TransactionMembershipPeriod = ({
  id,
  formData,
  setFormData
}) => {
  const [buyingMembership, setBuyingMembership] = useState(false)
  const [canBuyMembership, setCanBuyMembership] = useState(false);

  const {data, refetch} = useQuery(gql`
    query ($member_id: Int, $transaction_id: Int) {
      membership_periods(member_id: $member_id, transaction_id: $transaction_id) {
        name,
        id
      }
    }
  `, {
    skip: !buyingMembership,
    variables: {
      member_id: formData.who_member_id,
      transaction_id: id
    }
  })

  const membershipPeriods = get(data, 'membership_periods', []);

  // useEffect(() => {
  //   refetch();
  // }, [data.who_member_id])
  useEffect(() => {
    refetch();
  }, [id, formData.who_member_id])

  useEffect(() => {
    if (formData.membership_period_id) {
      setBuyingMembership(true)
    }
  }, [formData.membership_period_id, canBuyMembership])

  useEffect(() => {
    setCanBuyMembership(
      formData.who_member_id && formData.type === "INCOMING"
    );
  }, [formData.who_member_id, formData.type])
  useEffect(() => {
    if (!canBuyMembership) {
      setBuyingMembership(false)
    }
  }, [canBuyMembership])
  useEffect(() => {
    refetch();
    if (!buyingMembership) {
      setFormData(omit(formData, ['membership_period_id']))
    }
  }, [buyingMembership])

  const onChange = (event) => {
    setFormData({
      ...formData,
      membership_period_id: event.target.value
    })
  }

  return <>
    <FormControl fullWidth sx={{m:2}}>
      <FormControlLabel
        disabled={!canBuyMembership}
        control={
          <Switch
            checked={buyingMembership}
            onChange={(event) => setBuyingMembership(event.target.checked)}/>
        }
        label="Membership" />
    </FormControl>
    {buyingMembership && membershipPeriods.length > 0 && <FormControl fullWidth sx={{m: 2}}>
      <InputLabel id="membership-period">Membership Period</InputLabel>
      <Select
        labelId="membership-period"
        id="membership-period"
        value={`${get(formData, 'membership_period_id', '')}`}
        label="Membership Period"
        required
        onChange={onChange}
      >
        {membershipPeriods.map(({id, name}) => {
          return <MenuItem key={`${id}`} value={id}>{name}</MenuItem>
        })}
      </Select>
    </FormControl>}
  </>
}
