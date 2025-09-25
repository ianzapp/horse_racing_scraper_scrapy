# Define here the models for your scraped items
#
# See documentation in:
# https://docs.scrapy.org/en/latest/topics/items.html

import scrapy


class RaceEntryItem(scrapy.Item):
    # Race Information
    track = scrapy.Field()
    race_date = scrapy.Field()
    race_number = scrapy.Field()
    race_name = scrapy.Field()
    race_distance = scrapy.Field()
    race_surface = scrapy.Field()
    purse = scrapy.Field()

    # Horse Information
    horse_name = scrapy.Field()
    sire = scrapy.Field()
    age = scrapy.Field()
    sex = scrapy.Field()  # M/F/G from age field like "5G"
    hrn_power_ranking = scrapy.Field()  # The HRN number like "113*"

    # Racing Information
    post_position = scrapy.Field()
    morning_line_odds = scrapy.Field()

    # People
    jockey = scrapy.Field()
    trainer = scrapy.Field()
    owner = scrapy.Field()

    # Additional Fields
    weight = scrapy.Field()
    medication = scrapy.Field()
    equipment = scrapy.Field()
    claim_price = scrapy.Field()

    # Metadata
    entry_url = scrapy.Field()
    scraped_at = scrapy.Field()


class HorseRacingScraperScrapyItem(scrapy.Item):
    pass
